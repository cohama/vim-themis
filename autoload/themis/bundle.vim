" themis: Test bundle.
" Version: 1.1
" Author : thinca <thinca+vim@gmail.com>
" License: zlib License

let s:save_cpo = &cpo
set cpo&vim

let s:bundle = {
\   'suite': {
\     'title': {},
\   },
\   'children': [],
\ }

" FIXME: Duplicate function in rerport
function! s:bundle.get_full_title()
  let title = ''
  if has_key(self, 'parent')
    let t = self.parent.get_full_title()
    if !empty(t)
      let title = t . ' '
    endif
  endif
  return title . self.get_title()
endfunction

function! s:bundle.get_title()
  let title = get(self, 'title', '')
  if empty(title)
    let filename = get(self, 'filename', '')
    if !empty(filename)
      let title = fnamemodify(filename, ':t')
    endif
  endif
  return title
endfunction

function! s:bundle.get_description(name)
  return get(self.suite.title, a:name, '')
endfunction

function! s:bundle.add_child(bundle)
  if has_key(a:bundle, 'parent')
    call a:bundle.parent.remove_child(a:bundle)
  endif
  let self.children += [a:bundle]
  let a:bundle.parent = self
endfunction

function! s:bundle.get_child(title)
  for child in self.children
    if child.title ==# a:title
      return child
    endif
  endfor
  return {}
endfunction

function! s:bundle.remove_child(child)
  call filter(self.children, 'v:val isnot a:child')
endfunction

function! s:bundle.run_test(title)
  call self.suite[a:title]()
endfunction

function! themis#bundle#new(...)
  let bundle = deepcopy(s:bundle)
  for arg in a:000
    let t = type(arg)
    if t == type('')
      let bundle.title = arg
    endif
    unlet arg
  endfor
  return bundle
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
