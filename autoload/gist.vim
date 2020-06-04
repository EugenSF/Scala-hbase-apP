
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
    endif
  endif
  return gist_browser_command
endfunction

function! s:open_browser(url) abort
  let cmd = s:get_browser_command()
  if len(cmd) == 0
    redraw
    echohl WarningMsg
    echo 'It seems that you don''t have general web browser. Open URL below.'
    echohl None
    echo a:url
    return
  endif
  let quote = &shellxquote == '"' ?  "'" : '"'
  if cmd =~# '^!'
    let cmd = substitute(cmd, '%URL%', '\=quote.a:url.quote', 'g')
    silent! exec cmd
  elseif cmd =~# '^:[A-Z]'
    let cmd = substitute(cmd, '%URL%', '\=a:url', 'g')
    exec cmd
  else
    let cmd = substitute(cmd, '%URL%', '\=quote.a:url.quote', 'g')
    call system(cmd)
  endif
endfunction

function! s:shellwords(str) abort
  let words = split(a:str, '\%(\([^ \t\''"]\+\)\|''\([^\'']*\)''\|"\(\%([^\"\\]\|\\.\)*\)"\)\zs\s*\ze')
  let words = map(words, 'substitute(v:val, ''\\\([\\ ]\)'', ''\1'', "g")')
  let words = map(words, 'matchstr(v:val, ''^\%\("\zs\(.*\)\ze"\|''''\zs\(.*\)\ze''''\|.*\)$'')')
  return words
endfunction

function! s:truncate(str, num)
  let mx_first = '^\(.\)\(.*\)$'
  let str = a:str
  let ret = ''
  let width = 0
  while 1
    let char = substitute(str, mx_first, '\1', '')
    let cells = strdisplaywidth(char)
    if cells == 0 || width + cells > a:num
      break
    endif
    let width = width + cells
    let ret .= char
    let str = substitute(str, mx_first, '\2', '')
  endwhile
  while width + 1 <= a:num
    let ret .= ' '
    let width = width + 1
  endwhile
  return ret
endfunction

function! s:format_gist(gist) abort
  let files = sort(keys(a:gist.files))
  if empty(files)
    return ''
  endif
  let file = a:gist.files[files[0]]
  let name = file.filename
  if has_key(file, 'content')
    let code = file.content
    let code = "\n".join(map(split(code, "\n"), '"  ".v:val'), "\n")
  else
    let code = ''
  endif
  let desc = type(a:gist.description)==0 || a:gist.description ==# '' ? '' : a:gist.description
  let name = substitute(name, '[\r\n\t]', ' ', 'g')
  let name = substitute(name, '  ', ' ', 'g')
  let desc = substitute(desc, '[\r\n\t]', ' ', 'g')
  let desc = substitute(desc, '  ', ' ', 'g')
  " Display a nice formatted (and truncated if needed) table of gists on screen
  " Calculate field lengths for gist-listing formatting on screen
  redir =>a |exe 'sil sign place buffer='.bufnr('')|redir end
  let signlist = split(a, '\n')
  let width = winwidth(0) - ((&number||&relativenumber) ? &numberwidth : 0) - &foldcolumn - (len(signlist) > 2 ? 2 : 0)
  let idlen = 33
  let namelen = get(g:, 'gist_namelength', 30)
  let desclen = width - (idlen + namelen + 10)
  return printf('gist: %s %s %s', s:truncate(a:gist.id, idlen), s:truncate(name, namelen), s:truncate(desc, desclen))
endfunction