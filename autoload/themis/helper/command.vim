" themis: helper: Command base utilities.
" Version: 1.0
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

let s:f_type = type(function('type'))

let s:helper = {
\   '_prefix': '',
\   '_scopes': [],
\ }
let s:c = {}  " This is used in commands.

function! s:get_throws_args(value)
  return matchlist(a:value, '\v^\s*%(/(%(\\.|[^/])*)/)?\s*(.*)')[1 : 2]
endfunction

function! s:wrap_exception(exception, line)
  " TODO: Duplicate code
  let result = matchstr(a:exception, '\c^themis:\_s*report:\_s*\zs.*')
  if empty(result)
    let [type, message] = ['failure', a:exception]
  else
    let [type, message] =
    \   matchlist(result, '\v^%((\w+):\s*)?(.*)')[1 : 2]
  endif
  let func = split(expand('<sfile>'), '\.\.')[-2]
  throw printf("themis: report: %s: %s\n%3d: %s\n%s",
  \   type,
  \   'Error occurred line:',
  \   a:line,
  \   themis#util#funcline(func, a:line),
  \   message
  \ )
endfunction

function! s:fail(line, exception, expr, result)
  let func = split(expand('<sfile>'), '\.\.')[-2]
  throw themis#failure([
  \   'The truthy value was expected, but it was not the case.',
  \   'Error occurred line:',
  \   printf('%3d: %s', a:line, themis#util#funcline(func, a:line)),
  \   '',
  \   '    expected: truthy',
  \   '         got: ' . string(a:result),
  \ ])
endfunction

function! s:not_thrown(line, expected_exception, expr, result)
  let func = split(expand('<sfile>'), '\.\.')[-2]
  throw themis#failure([
  \   'An exception thrown was expected, but not thrown.',
  \   'Error occurred line:',
  \   printf('%3d: %s', a:line, themis#util#funcline(func, a:line)),
  \   '',
  \   '    expected exception: ' . string(a:expected_exception),
  \ ])
endfunction

function! s:check_exception(line, thrown_expection, expected_exception)
  if a:expected_exception != '' && a:thrown_expection !~# a:expected_exception
    let func = split(expand('<sfile>'), '\.\.')[-2]
    throw themis#failure([
    \   'An exception was expected, but not thrown.',
    \   'Error occurred line:',
    \   printf('%3d: %s', a:line, themis#util#funcline(func, a:line)),
    \   '',
    \   '    expected exception: ' . string(a:expected_exception),
    \   '      thrown exception: ' . string(a:thrown_expection),
    \ ])
  endif
endfunction

function! s:define_assert(prefix)
  let command = a:prefix . 'Assert'
  execute 'command! -nargs=+' command
  \ '  try'
  \ '|   call s:add_scopes(l:)'
  \ '|   let s:c.result = <args>'
  \ '| catch /^themis:\s*report:/'
  \ '|   call s:wrap_exception(v:exception, expand("<slnum>"))'
  \ '| finally'
  \ '|   call s:restore_scopes(l:)'
  \ '| endtry'
  \ '| if !s:check_truthy(s:c.result)'
  \ '|   call s:fail(expand("<slnum>"), "", <q-args>, s:c.result)'
  \ '| endif'
endfunction

function! s:define_throws(prefix)
  let command = a:prefix . 'Throws'
  execute 'command! -nargs=+' command
  \ '  let s:c.not_thrown = 0'
  \ '| let [s:c.expect_exception, s:c.expr] = s:get_throws_args(<q-args>)'
  \ '| if s:c.expr[0] == ":"'
  \ '|   try'
  \ '|     call s:add_scopes(l:)'
  \ '|     execute s:c.expr'
  \ '|     let s:c.result = 0'
  \ '|     let s:c.not_thrown = 1'
  \ '|   catch'
  \ '|     call s:check_exception(expand("<slnum>"), v:exception, s:c.expect_exception)'
  \ '|   finally'
  \ '|     call s:restore_scopes(l:)'
  \ '|   endtry'
  \ '| else'
  \ '|   try'
  \ '|     call s:add_scopes(l:)'
  \ '|     let s:c.result = eval(s:c.expr)'
  \ '|     let s:c.not_thrown = 1'
  \ '|   catch'
  \ '|     call s:check_exception(expand("<slnum>"), v:exception, s:c.expect_exception)'
  \ '|   finally'
  \ '|     call s:restore_scopes(l:)'
  \ '|   endtry'
  \ '| endif'
  \ '| if s:c.not_thrown'
  \ '|   call s:not_thrown(expand("<slnum>"), s:c.expect_exception, s:c.expr, s:c.result)'
  \ '| endif'
endfunction

function! s:define_fail(prefix)
  let command = a:prefix . 'Fail'
  execute 'command! -nargs=*' command
  \ '  if <q-args> !=# ""'
  \ '|   throw themis#failure(<q-args>)'
  \ '| else'
  \ '|   throw themis#failure("{message} of :Fail can not be empty.")'
  \ '| endif'
endfunction

function! s:define_todo(prefix)
  let command = a:prefix . 'TODO'
  execute 'command! -nargs=*' command
  \ 'throw "themis: report: todo:" . <q-args>'
endfunction

function! s:define_skip(prefix)
  let command = a:prefix . 'Skip'
  execute 'command! -nargs=*' command
  \ '  if <q-args> !=# ""'
  \ '|   throw "themis: report: SKIP:" . <q-args>'
  \ '| else'
  \ '|   throw themis#failure("{message} of :Skip can not be empty.")'
  \ '| endif'
endfunction

function! s:helper.prefix(prefix)
  let self._prefix = a:prefix
  return self
endfunction

function! s:helper.with(...)
  call extend(self._scopes, a:000)
  return self
endfunction

function! s:helper.define()
  call s:define_assert(self._prefix)
  call s:define_throws(self._prefix)
  call s:define_fail(self._prefix)
  call s:define_todo(self._prefix)
  call s:define_skip(self._prefix)
  let s:current_scopes = self._scopes
endfunction

function! s:helper.undef()
  call s:delcommand(self._prefix . 'Assert')
  call s:delcommand(self._prefix . 'Throws')
  call s:delcommand(self._prefix . 'Fail')
  call s:delcommand(self._prefix . 'TODO')
  call s:delcommand(self._prefix . 'Skip')
  unlet! s:current_scopes
endfunction


let s:events = {'helper': s:helper, 'nest': 0}
function! s:events.before_suite(bundle)
  if self.is_target(a:bundle)
    if self.nest == 0
      call self.helper.define()
    endif
    let self.nest += 1
  endif
endfunction

function! s:events.after_suite(bundle)
  if self.is_target(a:bundle)
    let self.nest -= 1
    if self.nest == 0
      call self.helper.undef()
    endif
  endif
endfunction

function! s:events.is_target(bundle)
  return self.filename ==# '' ||
  \      self.filename ==# get(a:bundle, 'filename', '')
endfunction

function! s:check_truthy(value)
  let t = type(a:value)
  return (t == type(0) || t == type('')) && a:value
endfunction

function! s:delcommand(cmd)
  if exists(':' . a:cmd) == 2
    execute 'delcommand' a:cmd
  endif
endfunction

function! s:add_scopes(local)
  if !exists('s:current_scopes')
    return
  endif
  let s:expanded = []
  for scope in s:current_scopes
    for [name, Value] in items(scope)
      if type(Value) == s:f_type
        let name = toupper(name[0]) . name[1 :]
      endif
      if !has_key(a:local, name)
        let a:local[name] = Value
        let s:expanded += [name]
      endif
      unlet! Value
    endfor
  endfor
endfunction

function! s:restore_scopes(local)
  if !exists('s:expanded')
    return
  endif
  for name in s:expanded
    call remove(a:local, name)
  endfor
  unlet s:expanded
endfunction

function! themis#helper#command#new(runner)
  let events = deepcopy(s:events)
  let events.filename = get(a:runner, '_filename', '')
  call a:runner.add_event(events)
  return events.helper
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
