"=============================================================================
" FILE: metarw/qiita.vim
" AUTHOR:  Tomohiro Hashidate (joker1007) <kakyoin.hierophant@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:qiita_token')
  echohl ErrorMsg | echomsg "require 'g:qiita_token' variables" | echohl None
  finish
endif

if !exists('g:qiita_user')
  echohl ErrorMsg | echomsg "require 'g:qiita_user' variables" | echohl None
  finish
endif

if !executable('curl')
  echohl ErrorMsg | echomsg "require 'curl' command" | echohl None
  finish
endif

function! s:endpoint_url() " {{{
  return "https://qiita.com/api/v1"
endfunction " }}}

function! s:qiita_path(path, auth) " {{{
  if a:auth
    let path = s:endpoint_url() . a:path . "?token=" . g:qiita_token

    if exists('g:qiita_per_page')
      let path = path . "&per_page=" . g:qiita_per_page
    endif
  else
    let path = s:endpoint_url() . a:path

    if exists('g:qiita_per_page')
      let path = path . "?per_page=" . g:qiita_per_page
    endif
  endif

  return path
endfunction " }}}

function! s:parse_title() " {{{
  return getline(1)
endfunction " }}}

function! s:parse_body() " {{{
  return join(getline(4, "$"), "\n")
endfunction " }}}

function! s:parse_tags() " {{{
  let line = getline(2)

  if line =~ "^\s*$/"
    return []
  else
    let result = {}

    let items = split(line, " ")
    for tag_info in items
      let name_and_version = split(tag_info, ":")
      if len(name_and_version) == 2
        let [name, tag_version] = name_and_version
        if has_key(result, name)
          call add(result[name], tag_version)
        else
          let result[name] = [tag_version]
        endif
      else
        let name = name_and_version[0]
        let result[name] = []
      endif
    endfor

    return result
  endif
endfunction " }}}

function! s:tags_to_line(_) " {{{
  let result = []
  for t in a:_
    if empty(t.versions)
      call add(result, t.name)
    else
      for v in t.versions
        call add(result, t.name . ":" . v)
      endfor
    endif
  endfor
  return join(result, " ")
endfunction " }}}

function! s:construct_post_data(options) " {{{
  let Private = a:options.private == 1 ?
        \ function('webapi#json#true') :
        \ function('webapi#json#false')

  let Tweet = a:options.tweet == 1 ?
        \ function('webapi#json#true') :
        \ function('webapi#json#false')

  let Gist = a:options.gist == 1 ?
        \ function('webapi#json#true') :
        \ function('webapi#json#false')

  let tag_info = []
  for [name, versions] in items(s:parse_tags())
    call add(tag_info, {'name' : name, 'versions' : versions})
  endfor

  let data = {
        \ "title" : s:parse_title(),
        \ "tags" : tag_info,
        \ "body" : s:parse_body(),
        \ "private" : Private,
        \ "tweet" : Tweet,
        \ "gist" : Gist,
        \ }

  return data
endfunction " }}}

function! s:post_current(options) " {{{
  echo a:options
  let data = s:construct_post_data(a:options)
  let json = webapi#json#encode(data)
  let res = webapi#http#post(s:qiita_path("/items", 1), json, {"Content-type" : "application/json"})
  let content = webapi#json#decode(res.content)

  if res.status =~ "^2.*"
    echomsg content.url
    return ['done', '']
  else
    return ['error', 'Failed to post new item']
  endif
endfunction " }}}

function! s:update_item(uuid, options) " {{{
  let data = s:construct_post_data(a:options)
  call remove(data, 'private')
  call remove(data, 'tweet')
  call remove(data, 'gist')
  let json = webapi#json#encode(data)
  let res = webapi#http#post(s:qiita_path("/items/" . a:uuid, 1), json, {"Content-type" : "application/json"}, "PUT")
  let content = webapi#json#decode(res.content)

  if res.status =~ "^2.*"
    echomsg content.url
    return ['done', '']
  else
    return ['error', 'Failed to update item']
  endif
endfunction " }}}

function! s:read_content(uuid) " {{{
  let res = webapi#http#get(s:qiita_path("/items/" . a:uuid, 1))
  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch item']
  endif

  let content = webapi#json#decode(res.content)

  let body = join([content.title, s:tags_to_line(content.tags), "", content.raw_body], "\n")
  put =body
  set ft=markdown

  if content.user.url_name == g:qiita_user
    let mine = 1
  else
    let mine = 0
  endif
  let b:qiita_metadata = {
        \ 'private' : content.private,
        \ 'url' : content.url,
        \ 'uuid' : content.uuid,
        \ 'stocked' : content.stocked,
        \ 'mine' : mine,
        \ 'user' : content.user.url_name,
        \}

  command! -buffer QiitaBrowse call s:open_browser()
  command! -buffer QiitaStock  call s:stock_item()
  return ['done', '']
endfunction " }}}

function! s:label_format() " {{{
  return 'v:val.title . " (" . v:val.stock_count . ")"'
endfunction " }}}

function! s:read_user(user) " {{{
  let res = webapi#http#get(s:qiita_path("/users/" . a:user . "/items", 1))
  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch items']
  endif

  let content = webapi#json#decode(res.content)
  let list = map(content,
    \ '{"label" : ' . s:label_format() . ', "fakepath" : "qiita:items/" . v:val.uuid}')
  echo list
  return ["browse", list]
endfunction " }}}

function! s:read_new_items() " {{{
  let res = webapi#http#get(s:qiita_path("/items", 0))
  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch items']
  endif

  let content = webapi#json#decode(res.content)
  let list = map(content,
    \ '{"label" : ' . s:label_format() . ', "fakepath" : "qiita:items/" . v:val.uuid}')
  echo list
  return ["browse", list]
endfunction " }}}

function! s:read_tag_items(tag) " {{{
  let res = webapi#http#get(s:qiita_path("/tags/" . a:tag . "/items", 1))
  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch items']
  endif

  let content = webapi#json#decode(res.content)
  let list = map(content,
    \ '{"label" : ' . s:label_format() . ', "fakepath" : "qiita:items/" . v:val.uuid}')
  echo list
  return ["browse", list]
endfunction " }}}

function! s:read_my_stocks() " {{{
  let res = webapi#http#get(s:qiita_path("/stocks", 1))
  if res.status !~ "^2.*"
    return ['error', 'Failed to fetch items']
  endif

  let content = webapi#json#decode(res.content)
  let list = map(content,
    \ '{"label" : ' . s:label_format() . ', "fakepath" : "qiita:items/" . v:val.uuid}')
  echo list
  return ["browse", list]
endfunction " }}}

function! s:parse_options(str) " {{{
  let result = {}
  let pairs = split(a:str, "&")
  for p in pairs
    let [key, value] = split(p, '=')
    let result[key] = value
  endfor
  return result
endfunction " }}}

function! s:open_browser() " {{{
  if exists('b:qiita_metadata')
    call openbrowser#open(b:qiita_metadata.url)
  else
    echoerr 'Current buffer is not qiita post'
  endif
endfunction " }}}

function! s:stock_item() " {{{
  if exists('b:qiita_metadata')
    let res = webapi#http#post(s:qiita_path("/items/" . b:qiita_metadata.uuid . "/stock", 1), {}, {}, "PUT")
    if res.status =~ "^2.*"
      let b:qiita_metadata.stocked = 1
      echomsg "Stocked."
    else
      echoerr "Failed to stocked."
    endif
  else
    echoerr 'Current buffer is not qiita post'
  endif
endfunction " }}}

function! s:parse_incomplete_fakepath(incomplete_fakepath) " {{{
  let _ = {
        \ 'mode' : '',
        \ 'path' : '',
        \ 'options' : {'private' : 0, 'tweet' : 0, 'gist' : 0}
        \ }

  let fragments = split(a:incomplete_fakepath, '^\l\+\zs:', !0)
  if len(fragments) <= 1
    echoerr 'Unexpected a:incomplete_fakepath:' string(a:incomplete_fakepath)
    throw 'metarw:qiita#e1'
  endif

  let _.scheme = fragments[0]

  let path_fragments = split(fragments[1], '?', !0)
  " parse option parameter
  if len(path_fragments) == 2
    call extend(_.options, s:parse_options(path_fragments[1]), 'force')
    let fragments[1] = path_fragments[0]
  elseif len(path_fragments) >= 3
    echoerr 'path is invalid'
    return _
  endif

  if empty(fragments[1])
    let _.mode = 'write_new'
  else
    let fragments = [fragments[0]] + split(fragments[1], '[\/]', !0)

    if len(fragments) == 3
      if fragments[1] == "items"
        let _.mode = 'items'
        let _.path = fragments[2]
      elseif fragments[1] == "users"
        let _.mode = 'users'
        let _.path = fragments[2]
      elseif fragments[1] == "tags"
        let _.mode = 'tag_items'
        let _.path = fragments[2]
      endif
    elseif len(fragments) == 2
      if fragments[1] == "items"
        let _.mode = 'new_items'
      elseif fragments[1] == "stocks"
        let _.mode = 'my_stocks'
      endif
    endif
  endif

  return _
endfunction " }}}

function! metarw#qiita#read(fakepath) " {{{
  let _ = s:parse_incomplete_fakepath(a:fakepath)
  if _.mode == "items"
    return s:read_content(_.path)
  elseif _.mode == "users"
    return s:read_user(_.path)
  elseif _.mode == "new_items"
    return s:read_new_items()
  elseif _.mode == "tag_items"
    return s:read_tag_items(_.path)
  elseif _.mode == "my_stocks"
    return s:read_my_stocks()
  endif
endfunction " }}}

function! metarw#qiita#write(fakepath, line1, line2, append_p) " {{{
  let _ = s:parse_incomplete_fakepath(a:fakepath)
  if _.mode == "write_new"
    let result = s:post_current(_.options)
  elseif _.mode == "items"
    let result = s:update_item(_.path, _.options)
  else
    let result = ['done', '']
  endif
  return result
endfunction " }}}

" Nop
function! metarw#qiita#complete(arglead, cmdline, cursorpos) " {{{
  return []
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
