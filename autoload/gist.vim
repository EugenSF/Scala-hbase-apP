
"=============================================================================
" File: gist.vim
" Author: Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Last Change: 10-Oct-2016.
" Version: 7.3
" WebPage: http://github.com/mattn/vim-gist
" License: BSD

let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:gist_disabled') && g:gist_disabled == 1
  function! gist#Gist(...) abort
  endfunction
  finish
endif

if !exists('g:github_user') && !executable('git')
  echohl ErrorMsg | echomsg 'Gist: require ''git'' command' | echohl None
  finish
endif

if !executable('curl')
  echohl ErrorMsg | echomsg 'Gist: require ''curl'' command' | echohl None
  finish
endif

if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
  echohl ErrorMsg | echomsg 'Gist: require ''webapi'', install https://github.com/mattn/webapi-vim' | echohl None
  finish
else
  call webapi#json#true()
endif

let s:gist_token_file = expand(get(g:, 'gist_token_file', '~/.gist-vim'))
let s:system = function(get(g:, 'webapi#system_function', 'system'))

if !exists('g:github_user')
  let g:github_user = substitute(s:system('git config --get github.user'), "\n", '', '')
  if strlen(g:github_user) == 0
    let g:github_user = $GITHUB_USER