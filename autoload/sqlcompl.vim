"
" Author: kamichidu
" Last Change: 05-Jan-2014.
" Lisence: The MIT License (MIT)
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
"
let s:save_cpo= &cpo
set cpo&vim

let s:V= vital#of('neocomplete-sqlcompl')
let s:L= s:V.import('Data.List')
let s:P= s:V.import('Process')
unlet s:V

" variables {{{
let s:config_default= {
\   'server_host': '127.0.0.1',
\   'server_port': 12345,
\}
" }}}

" make s:keywords {{{
let s:filename= globpath(&runtimepath, 'autoload/keyword')
if filereadable(s:filename)
    let s:keywords= readfile(s:filename)
else
    let s:keywords= []
endif
lockvar s:keywords
unlet s:filename
" }}}
function! sqlcompl#looks_like_keyword(s) " {{{
    let l:min_pattern_length= 2
    let l:keywords= filter(copy(s:keywords), 'len(v:val) >= l:min_pattern_length')

    let l:keyword_pattern= '^\c\%(' . join(map(l:keywords, 's:keyword_matcher(v:val, l:min_pattern_length)'), '\|') . '\)$'

    return a:s =~ l:keyword_pattern
endfunction

function! s:keyword_matcher(s, min_length)
    if len(a:s) > a:min_length
        return strpart(a:s, 0, a:min_length) . '\%[' . strpart(a:s, a:min_length) . ']'
    else
        return a:s
    endif
endfunction
" }}}
function! sqlcompl#launch_server() " {{{
    let l:cmd= join(
    \   [
    \       'perl',
    \       globpath(&runtimepath, 'bin/anal.pl'),
    \   ],
    \   ' '
    \)
    call s:P.spawn(l:cmd)
endfunction
" }}}
function! sqlcompl#terminate_server() " {{{
    try
        let l:client= jsonrpc#client(s:config_default.server_host, s:config_default.server_port)

        call l:client.call('exit')
    catch /.*/
        echoerr 'sqlcompl: caught an exception on terminate ... ' . v:exception
    endtry
endfunction
" }}}
function! sqlcompl#connect() " {{{
    return jsonrpc#client(s:config_default.server_host, s:config_default.server_port)
endfunction
" }}}
function! sqlcompl#within_comment() " {{{
    return getline('.') =~# '--.*$'
endfunction
" }}}

"""
" cache utility.
""
function! sqlcompl#cache()
    let l:obj= {
    \   '_cache': {},
    \}

    function! l:obj.has(key)
        return has_key(self._cache, a:key)
    endfunction

    function! l:obj.get(key)
        return self._cache[a:key]
    endfunction

    function! l:obj.set(key, value)
        let self._cache[a:key]= a:value
    endfunction

    return l:obj
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
" vim: foldenable:foldmethod=marker
