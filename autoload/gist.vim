
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

" Note: A colon in the file name has side effects on Windows due to NTFS Alternate Data Streams; avoid it.
let s:bufprefix = 'gist' . (has('unix') ? ':' : '_')
function! s:GistList(gistls, page, pagelimit) abort
  if a:gistls ==# '-all'
    let url = g:gist_api_url.'gists/public'
  elseif get(g:, 'gist_show_privates', 0) && a:gistls ==# 'starred'
    let url = g:gist_api_url.'gists/starred'
  elseif get(g:, 'gist_show_privates') && a:gistls ==# 'mine'
    let url = g:gist_api_url.'gists'
  else
    let url = g:gist_api_url.'users/'.a:gistls.'/gists'
  endif
  let winnum = bufwinnr(bufnr(s:bufprefix.a:gistls))
  if winnum != -1
    if winnum != bufwinnr('%')
      exe winnum 'wincmd w'
    endif
    setlocal modifiable
  else
    if get(g:, 'gist_list_vsplit', 0)
      exec 'silent noautocmd vsplit +set\ winfixwidth ' s:bufprefix.a:gistls
    elseif get(g:, 'gist_list_rightbelow', 0)
      exec 'silent noautocmd rightbelow 5 split +set\ winfixheight ' s:bufprefix.a:gistls
    else
      exec 'silent noautocmd split' s:bufprefix.a:gistls
    endif
  endif

  let url = url . '?per_page=' . a:pagelimit
  if a:page > 1
    let oldlines = getline(0, line('$'))
    let url = url . '&page=' . a:page
  endif

  setlocal modifiable
  let old_undolevels = &undolevels
  let oldlines = []
  silent %d _

  redraw | echon 'Listing gists... '
  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    bw!
    redraw
    echohl ErrorMsg | echomsg v:errmsg | echohl None
    return
  endif
  let res = webapi#http#get(url, '', { 'Authorization': auth })
  if v:shell_error != 0
    bw!
    redraw
    echohl ErrorMsg | echomsg 'Gists not found' | echohl None
    return
  endif
  let content = webapi#json#decode(res.content)
  if type(content) == 4 && has_key(content, 'message') && len(content.message)
    bw!
    redraw
    echohl ErrorMsg | echomsg content.message | echohl None
    if content.message ==# 'Bad credentials'
      call delete(s:gist_token_file)
    endif
    return
  endif

  let lines = map(filter(content, '!empty(v:val.files)'), 's:format_gist(v:val)')
  call setline(1, split(join(lines, "\n"), "\n"))

  $put='more...'

  let b:gistls = a:gistls
  let b:page = a:page
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal cursorline
  setlocal nomodified
  setlocal nomodifiable
  syntax match SpecialKey /^gist:/he=e-1
  syntax match Title /^gist: \S\+/hs=s+5 contains=ALL
  nnoremap <silent> <buffer> <cr> :call <SID>GistListAction(0)<cr>
  nnoremap <silent> <buffer> o :call <SID>GistListAction(0)<cr>
  nnoremap <silent> <buffer> b :call <SID>GistListAction(1)<cr>
  nnoremap <silent> <buffer> y :call <SID>GistListAction(2)<cr>
  nnoremap <silent> <buffer> p :call <SID>GistListAction(3)<cr>
  nnoremap <silent> <buffer> <esc> :bw<cr>
  nnoremap <silent> <buffer> <s-cr> :call <SID>GistListAction(1)<cr>

  cal cursor(1+len(oldlines),1)
  nohlsearch
  redraw | echo ''
endfunction

function! gist#list_recursively(user, ...) abort
  let use_cache = get(a:000, 0, 1)
  let limit = get(a:000, 1, -1)
  let verbose = get(a:000, 2, 1)
  if a:user ==# 'mine'
    let url = g:gist_api_url . 'gists'
  elseif a:user ==# 'starred'
    let url = g:gist_api_url . 'gists/starred'
  else
    let url = g:gist_api_url.'users/'.a:user.'/gists'
  endif

  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    " anonymous user cannot get gists to prevent infinite recursive loading
    return []
  endif

  if use_cache && exists('g:gist_list_recursively_cache')
    if has_key(g:gist_list_recursively_cache, a:user)
      return webapi#json#decode(g:gist_list_recursively_cache[a:user])
    endif
  endif

  let page = 1
  let gists = []
  let lastpage = -1

  function! s:get_lastpage(res) abort
    let links = split(a:res.header[match(a:res.header, 'Link')], ',')
    let link = links[match(links, 'rel=[''"]last[''"]')]
    let page = str2nr(matchlist(link, '\%(page=\)\(\d\+\)')[1])
    return page
  endfunction

  if verbose > 0
    redraw | echon 'Loading gists...'
  endif

  while limit == -1 || page <= limit
    let res = webapi#http#get(url.'?page='.page, '', {'Authorization': auth})
    if limit == -1
      " update limit to the last page
      let limit = s:get_lastpage(res)
    endif
    if verbose > 0
      redraw | echon 'Loading gists... ' . page . '/' . limit . ' pages has loaded.'
    endif
    let gists = gists + webapi#json#decode(res.content)
    let page = page + 1
  endwhile
  let g:gist_list_recursively_cache = get(g:, 'gist_list_recursively_cache', {})
  let g:gist_list_recursively_cache[a:user] = webapi#json#encode(gists)
  return gists
endfunction

function! gist#list(user, ...) abort
  let page = get(a:000, 0, 0)
  if a:user ==# '-all'
    let url = g:gist_api_url.'gists/public'
  elseif get(g:, 'gist_show_privates', 0) && a:user ==# 'starred'
    let url = g:gist_api_url.'gists/starred'
  elseif get(g:, 'gist_show_privates') && a:user ==# 'mine'
    let url = g:gist_api_url.'gists'
  else
    let url = g:gist_api_url.'users/'.a:user.'/gists'
  endif

  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    return []
  endif
  let res = webapi#http#get(url, '', { 'Authorization': auth })
  return webapi#json#decode(res.content)
endfunction

function! s:GistGetFileName(gistid) abort
  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    return ''
  endif
  let res = webapi#http#get(g:gist_api_url.'gists/'.a:gistid, '', { 'Authorization': auth })
  let gist = webapi#json#decode(res.content)
  if has_key(gist, 'files')
    return sort(keys(gist.files))[0]
  endif
  return ''
endfunction

function! s:GistDetectFiletype(gistid) abort
  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    return ''
  endif
  let res = webapi#http#get(g:gist_api_url.'gists/'.a:gistid, '', { 'Authorization': auth })
  let gist = webapi#json#decode(res.content)
  let filename = sort(keys(gist.files))[0]
  let ext = fnamemodify(filename, ':e')
  if has_key(s:extmap, ext)
    let type = s:extmap[ext]
  else
    let type = get(gist.files[filename], 'type', 'text')
  endif
  silent! exec 'setlocal ft='.tolower(type)
endfunction

function! s:GistWrite(fname) abort
  if substitute(a:fname, '\\', '/', 'g') == expand("%:p:gs@\\@/@")
    if g:gist_update_on_write != 2 || v:cmdbang
      Gist -e
    else
      echohl ErrorMsg | echomsg 'Please type ":w!" to update a gist.' | echohl None
    endif
  else
    exe 'w'.(v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:fname)
    silent! exe 'file' fnameescape(a:fname)
    silent! au! BufWriteCmd <buffer>
  endif
endfunction

function! s:GistGet(gistid, clipboard) abort
  redraw | echon 'Getting gist... '
  let res = webapi#http#get(g:gist_api_url.'gists/'.a:gistid, '', { 'Authorization': s:GistGetAuthHeader() })
  if res.status =~# '^2'
    try
      let gist = webapi#json#decode(res.content)
    catch
      redraw
      echohl ErrorMsg | echomsg 'Gist seems to be broken' | echohl None
      return
    endtry
    if get(g:, 'gist_get_multiplefile', 0) != 0
      let num_file = len(keys(gist.files))
    else
      let num_file = 1
    endif
    redraw
    if num_file > len(keys(gist.files))
      echohl ErrorMsg | echomsg 'Gist not found' | echohl None
      return
    endif
    augroup GistWrite
      au!
    augroup END
    for n in range(num_file)
      try
        let old_undolevels = &undolevels
        let filename = sort(keys(gist.files))[n]

        let winnum = bufwinnr(bufnr(s:bufprefix.a:gistid.'/'.filename))
        if winnum != -1
          if winnum != bufwinnr('%')
            exe winnum 'wincmd w'
          endif
          setlocal modifiable
        else
          if num_file == 1
            if get(g:, 'gist_edit_with_buffers', 0)
              let found = -1
              for wnr in range(1, winnr('$'))
                let bnr = winbufnr(wnr)
                if bnr != -1 && !empty(getbufvar(bnr, 'gist'))
                  let found = wnr
                  break
                endif
              endfor
              if found != -1
                exe found 'wincmd w'
                setlocal modifiable
              else
                if get(g:, 'gist_list_vsplit', 0)
                  exec 'silent noautocmd rightbelow vnew'
                else
                  exec 'silent noautocmd rightbelow new'
                endif
              endif
            else
              silent only!
              if get(g:, 'gist_list_vsplit', 0)
                exec 'silent noautocmd rightbelow vnew'
              else
                exec 'silent noautocmd rightbelow new'
              endif
            endif
          else
            if get(g:, 'gist_list_vsplit', 0)
              exec 'silent noautocmd rightbelow vnew'
            else
              exec 'silent noautocmd rightbelow new'
            endif
          endif
          setlocal noswapfile
          silent exec 'noautocmd file' s:bufprefix.a:gistid.'/'.fnameescape(filename)
        endif
        set undolevels=-1
        filetype detect
        silent %d _

        let content = gist.files[filename].content
        call setline(1, split(content, "\n"))
        let b:gist = {
        \ 'filename': filename,
        \ 'id': gist.id,
        \ 'description': gist.description,
        \ 'private': gist.public =~# 'true',
        \}
      catch
        let &undolevels = old_undolevels
        bw!
        redraw
        echohl ErrorMsg | echomsg 'Gist contains binary' | echohl None
        return
      endtry
      let &undolevels = old_undolevels
      setlocal buftype=acwrite bufhidden=hide noswapfile
      setlocal nomodified
      doau StdinReadPost,BufRead,BufReadPost
      let gist_detect_filetype = get(g:, 'gist_detect_filetype', 0)
      if (&ft ==# '' && gist_detect_filetype == 1) || gist_detect_filetype == 2
        call s:GistDetectFiletype(a:gistid)
      endif
      if a:clipboard
        if exists('g:gist_clip_command')
          exec 'silent w !'.g:gist_clip_command
        elseif has('clipboard')
          silent! %yank +
        else
          %yank
        endif
      endif
      1
      augroup GistWrite
        au! BufWriteCmd <buffer> call s:GistWrite(expand("<amatch>"))
      augroup END
    endfor
  else
    bw!
    redraw
    echohl ErrorMsg | echomsg 'Gist not found' | echohl None
    return
  endif
endfunction

function! s:GistListAction(mode) abort
  let line = getline('.')
  let mx = '^gist:\s*\zs\(\w\+\)\ze.*'
  if line =~# mx
    let gistid = matchstr(line, mx)
    if a:mode == 1
      call s:open_browser('https://gist.github.com/' . gistid)
    elseif a:mode == 0
      call s:GistGet(gistid, 0)
      wincmd w
      bw
    elseif a:mode == 2
      call s:GistGet(gistid, 1)
      " TODO close with buffe rname
      bdelete
      bdelete
    elseif a:mode == 3
      call s:GistGet(gistid, 1)
      " TODO close with buffe rname
      bdelete
      bdelete
      normal! "+p
    endif
    return
  endif
  if line =~# '^more\.\.\.$'
    call s:GistList(b:gistls, b:page+1, g:gist_per_page_limit)
    return
  endif
endfunction

function! s:GistUpdate(content, gistid, gistnm, desc) abort
  let gist = { 'id': a:gistid, 'files' : {}, 'description': '','public': function('webapi#json#true') }
  if exists('b:gist')
    if has_key(b:gist, 'filename') && len(a:gistnm) > 0
      let gist.files[b:gist.filename] = { 'content': '', 'filename': b:gist.filename }
      let b:gist.filename = a:gistnm
    endif
    if has_key(b:gist, 'private') && b:gist.private | let gist['public'] = function('webapi#json#false') | endif
    if has_key(b:gist, 'description') | let gist['description'] = b:gist.description | endif
    if has_key(b:gist, 'filename') | let filename = b:gist.filename | endif
  else
    let filename = a:gistnm
    if len(filename) == 0 | let filename = s:GistGetFileName(a:gistid) | endif
    if len(filename) == 0 | let filename = s:get_current_filename(1) | endif
  endif

  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    redraw
    echohl ErrorMsg | echomsg v:errmsg | echohl None
    return
  endif

  " Update description
  " If no new description specified, keep the old description
  if a:desc !=# ' '
    let gist['description'] = a:desc
  else
    let res = webapi#http#get(g:gist_api_url.'gists/'.a:gistid, '', { 'Authorization': auth })
    if res.status =~# '^2'
      let old_gist = webapi#json#decode(res.content)
      let gist['description'] = old_gist.description
    endif
  endif

  let gist.files[filename] = { 'content': a:content, 'filename': filename }

  redraw | echon 'Updating gist... '
  let res = webapi#http#post(g:gist_api_url.'gists/' . a:gistid,
  \ webapi#json#encode(gist), {
  \   'Authorization': auth,
  \   'Content-Type': 'application/json',
  \})
  if res.status =~# '^2'
    let obj = webapi#json#decode(res.content)
    let loc = obj['html_url']
    let b:gist = {'id': a:gistid, 'filename': filename}
    setlocal nomodified
    redraw | echomsg 'Done: '.loc
  else
    let loc = ''
    echohl ErrorMsg | echomsg 'Post failed: ' . res.message | echohl None
  endif
  return loc
endfunction

function! s:GistDelete(gistid) abort
  let auth = s:GistGetAuthHeader()
  if len(auth) == 0
    redraw
    echohl ErrorMsg | echomsg v:errmsg | echohl None
    return
  endif

  redraw | echon 'Deleting gist... '
  let res = webapi#http#post(g:gist_api_url.'gists/'.a:gistid, '', {
  \   'Authorization': auth,
  \   'Content-Type': 'application/json',
  \}, 'DELETE')
  if res.status =~# '^2'
    if exists('b:gist')
      unlet b:gist
    endif
    redraw | echomsg 'Done: '
  else
    echohl ErrorMsg | echomsg 'Delete failed: ' . res.message | echohl None
  endif
endfunction

function! s:get_current_filename(no) abort
  let filename = expand('%:t')
  if len(filename) == 0 && &ft !=# ''
    let pair = filter(items(s:extmap), 'v:val[1] == &ft')
    if len(pair) > 0
      let filename = printf('gistfile%d%s', a:no, pair[0][0])
    endif
  endif
  if filename ==# ''
    let filename = printf('gistfile%d.txt', a:no)
  endif
  return filename
endfunction

function! s:update_GistID(id) abort
  let view = winsaveview()
  normal! gg
  let ret = 0
  if search('\<GistID\>:\s*$')
    let line = getline('.')
    let line = substitute(line, '\s\+$', '', 'g')
    call setline('.', line . ' ' . a:id)
    let ret = 1
  endif
  call winrestview(view)
  return ret
endfunction

" GistPost function:
"   Post new gist to github
"
"   if there is an embedded gist url or gist id in your file,
"   it will just update it.
"                                                   -- by c9s
"
"   embedded gist id format:
"
"       GistID: 123123
"
function! s:GistPost(content, private, desc, anonymous) abort
  let gist = { 'files' : {}, 'description': '','public': function('webapi#json#true') }
  if a:desc !=# ' ' | let gist['description'] = a:desc | endif
  if a:private | let gist['public'] = function('webapi#json#false') | endif
  let filename = s:get_current_filename(1)
  let gist.files[filename] = { 'content': a:content, 'filename': filename }

  let header = {'Content-Type': 'application/json'}
  if !a:anonymous
    let auth = s:GistGetAuthHeader()
    if len(auth) == 0
      redraw
      echohl ErrorMsg | echomsg v:errmsg | echohl None
      return
    endif
    let header['Authorization'] = auth
  endif

  redraw | echon 'Posting it to gist... '
  let res = webapi#http#post(g:gist_api_url.'gists', webapi#json#encode(gist), header)
  if res.status =~# '^2'
    let obj = webapi#json#decode(res.content)
    let loc = obj['html_url']
    let b:gist = {
    \ 'filename': filename,
    \ 'id': matchstr(loc, '[^/]\+$'),
    \ 'description': gist['description'],
    \ 'private': a:private,
    \}
    if s:update_GistID(b:gist['id'])
      Gist -e
    endif
    redraw | echomsg 'Done: '.loc
  else
    let loc = ''
    echohl ErrorMsg | echomsg 'Post failed: '. res.message | echohl None
  endif
  return loc
endfunction

function! s:GistPostBuffers(private, desc, anonymous) abort
  let bufnrs = range(1, bufnr('$'))
  let bn = bufnr('%')
  let query = []

  let gist = { 'files' : {}, 'description': '','public': function('webapi#json#true') }
  if a:desc !=# ' ' | let gist['description'] = a:desc | endif
  if a:private | let gist['public'] = function('webapi#json#false') | endif

  let index = 1
  for bufnr in bufnrs
    if !bufexists(bufnr) || buflisted(bufnr) == 0
      continue
    endif
    echo 'Creating gist content'.index.'... '
    silent! exec 'buffer!' bufnr
    let content = join(getline(1, line('$')), "\n")
    let filename = s:get_current_filename(index)
    let gist.files[filename] = { 'content': content, 'filename': filename }
    let index = index + 1
  endfor
  silent! exec 'buffer!' bn

  let header = {'Content-Type': 'application/json'}
  if !a:anonymous
    let auth = s:GistGetAuthHeader()
    if len(auth) == 0
      redraw
      echohl ErrorMsg | echomsg v:errmsg | echohl None
      return
    endif
    let header['Authorization'] = auth
  endif

  redraw | echon 'Posting it to gist... '
  let res = webapi#http#post(g:gist_api_url.'gists', webapi#json#encode(gist), header)
  if res.status =~# '^2'
    let obj = webapi#json#decode(res.content)
    let loc = obj['html_url']
    let b:gist = {
    \ 'filename': filename,
    \ 'id': matchstr(loc, '[^/]\+$'),
    \ 'description': gist['description'],
    \ 'private': a:private,