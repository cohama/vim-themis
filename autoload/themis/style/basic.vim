" themis: style: basic: Basic style.
" Version: 1.1
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

let s:func_t = type(function('type'))
let s:special_names = [
\   'before',
\   'after',
\   'before_each',
\   'after_each',
\ ]
let s:describe_pattern = '^__.\+__$'

let s:receiver = {}

function! s:receiver.script_loaded(runner)
  call s:load_nested_bundle(a:runner, a:runner.bundle)
endfunction

function! s:load_nested_bundle(runner, bundle)
  let a:runner.current_bundle = a:bundle
  let suite = copy(a:bundle.suite)
  call filter(suite, 'v:key =~# s:describe_pattern')
  for name in s:names_by_defined_order(suite)
    call suite[name]()
  endfor

  for child in a:bundle.children
    call s:load_nested_bundle(a:runner, child)
  endfor
endfunction

function! s:receiver.before_suite(bundle)
  if has_key(a:bundle.suite, 'before')
    call a:bundle.suite.before()
  endif
endfunction

function! s:receiver.before_test(bundle, name)
  if has_key(a:bundle, 'parent')
    call self.before_test(a:bundle.parent, a:name)
  endif
  if has_key(a:bundle.suite, 'before_each')
    call a:bundle.suite.before_each()
  endif
endfunction

function! s:receiver.after_suite(bundle)
  if has_key(a:bundle.suite, 'after')
    call a:bundle.suite.after()
  endif
endfunction

function! s:receiver.after_test(bundle, name)
  if has_key(a:bundle.suite, 'after_each')
    call a:bundle.suite.after_each()
  endif
  if has_key(a:bundle, 'parent')
    call self.after_test(a:bundle.parent, a:name)
  endif
endfunction


let s:style = {
\   'receiver': s:receiver,
\ }

function! s:style.get_test_names(bundle)
  let suite = copy(a:bundle.suite)
  call filter(suite, 'type(v:val) == s:func_t')
  call filter(suite, 'index(s:special_names, v:key) < 0')
  call filter(suite, 'v:key !~# s:describe_pattern')
  return s:names_by_defined_order(suite)
endfunction

function! s:names_by_defined_order(suite)
  return sort(keys(a:suite), 's:test_compare', a:suite)
endfunction

function! s:test_compare(a, b) dict
  let a_order = s:to_i(themis#util#funcname(self[a:a]))
  let b_order = s:to_i(themis#util#funcname(self[a:b]))
  return a_order ==# b_order ? 0 : b_order < a_order ? 1 : -1
endfunction

function! s:to_i(value)
  return a:value =~# '^\d\+$' ? str2nr(a:value) : a:value
endfunction

function! s:style.can_handle(filename)
  return fnamemodify(a:filename, ':e') ==? 'vim'
endfunction

function! s:style.load_script(filename)
  source `=a:filename`
endfunction

function! themis#style#basic#new(runner)
  let style = deepcopy(s:style)
  call a:runner.add_event(style.receiver)
  return style
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
