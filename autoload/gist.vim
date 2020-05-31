
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
  end
endif

if !exists('g:gist_api_url')
  let g:gist_api_url = substitute(s:system('git config --get github.apiurl'), "\n", '', '')
  if strlen(g:gist_api_url) == 0
    let g:gist_api_url = 'https://api.github.com/'
  end
  if exists('g:github_api_url') && !exists('g:gist_shutup_issue154')
    if matchstr(g:gist_api_url, 'https\?://\zs[^/]\+\ze') != matchstr(g:github_api_url, 'https\?://\zs[^/]\+\ze')
      echohl WarningMsg
      echo '--- Warning ---'
      echo 'It seems that you set different URIs for github_api_url/gist_api_url.'
      echo 'If you want to remove this message: let g:gist_shutup_issue154 = 1'
      echohl None
      if confirm('Continue?', '&Yes\n&No') != 1
        let g:gist_disabled = 1
        finish
      endif
      redraw!
    endif
  endif
endif
if g:gist_api_url !~# '/$'
  let g:gist_api_url .= '/'
endif

if !exists('g:gist_update_on_write')
  let g:gist_update_on_write = 1
endif

function! s:get_browser_command() abort
  let gist_browser_command = get(g:, 'gist_browser_command', '')
  if gist_browser_command ==# ''
    if has('win32') || has('win64')
      let gist_browser_command = '!start rundll32 url.dll,FileProtocolHandler %URL%'
    elseif has('mac') || has('macunix') || has('gui_macvim') || system('uname') =~? '^darwin'
      let gist_browser_command = 'open %URL%'
    elseif executable('xdg-open')
      let gist_browser_command = 'xdg-open %URL%'
    elseif executable('firefox')
      let gist_browser_command = 'firefox %URL% &'
    else
      let gist_browser_command = ''