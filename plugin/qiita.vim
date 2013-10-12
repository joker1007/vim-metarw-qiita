"=============================================================================
" FILE: qiita.vim
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

command! QiitaMine execute "edit qiita:users/" . g:qiita_user
command! QiitaPost write qiita:
command! QiitaNewItems execute "edit qiita:items/"
command! -nargs=1 QiitaOpen execute "edit qiita:items/" . "<args>"
command! -nargs=1 QiitaUserItems execute "edit qiita:users/" . "<args>"
command! -nargs=1 QiitaTagItems execute "edit qiita:tags/" . "<args>"

let &cpo = s:save_cpo
unlet s:save_cpo
