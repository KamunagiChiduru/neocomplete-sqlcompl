"
" Author: kamichidu
" Last Change: 11-Dec-2013.
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
unlet s:V

let s:source= {
\   'name': 'sqlcompl',
\   'kind': 'manual',
\   'filetypes': {'sql': 1},
\   'hooks': {},
\}

function! neocomplete#sources#sqlcompl#define()
    return s:source
endfunction

function! s:source.get_complete_position(context)
    if neocomplete#within_comment()
        return -1
    endif

    " columns completion
    if a:context.input =~ '\.[a-zA-Z0-9_]*$'
        return match(a:context.input, '\.\zs[a-zA-Z0-9_]*$')
        " tables completion
    elseif a:context.input =~ '\<[a-zA-Z0-9_]\+$'
        return match(a:context.input, '\<\zs[a-zA-Z0-9_]\+$')
    endif

    return -1
endfunction

function! s:source.gather_candidates(context)
    let l:baumkuchen= baumkuchen#of({
    \   'ranges':      [[1, 5], [line('$') - 4, line('$')]],
    \   'keys':        ['\<dbtype\>', '\<host\>', '\<port\>', '\<dbname\>', '\<username\>', '\<password\>'],
    \   'assignments': ['\s*=\s*'],
    \   'values':      ['[a-zA-Z0-9-_.]\+'],
    \})
    let l:config= l:baumkuchen.map('%')

    if !has_key(l:config, 'dbname')
        return []
    endif

    let l:method= ''
    let l:analinfo= {}
    " dot completion
    if a:context.input =~# '[a-zA-Z0-9-_]\+\.[a-zA-Z0-9-_]*$'
        let l:alias= matchstr(a:context.input, '\zs[a-zA-Z0-9-_]\+\ze\.[a-zA-Z0-9-_]*$')
        let l:table= s:resolve_alias(l:alias)

        let l:method= 'columns'
        let l:analinfo.table= l:table
    else
        let l:method= 'tables'
        let l:analinfo.schema= 'public'
    endif

    try
        let l:client= jsonrpc#client('127.0.0.1', 12345)

        let l:candidates= l:client.call(l:method, extend({
        \   'dbtype': get(l:config, 'dbtype', 'pg'),
        \   'host': get(l:config, 'host', 'localhost'),
        \   'port': get(l:config, 'port', 5432),
        \   'dbname': l:config.dbname,
        \   'username': get(l:config, 'username', 'postgres'),
        \   'password': get(l:config, 'password', 'postgres'),
        \}, l:analinfo))
    catch /.*/
        echoerr 'sqlcompl: caught an exception ... ' . v:exception
    finally
        if exists('l:client')
            call l:client.close()
        endif
    endtry

    return map(l:candidates, 's:new_candidate(v:val)')
endfunction

function! s:new_candidate(table)
    return {
    \   'word': a:table.name,
    \   'menu': get(a:table, 'type', 'unknown'),
    \   'kind': '[Sql]',
    \}
endfunction

function! s:resolve_alias(alias)
    let l:definition_pattern= '\<[a-zA-Z0-9-_]\+\s\+\(as\s\+\)\=' . a:alias . '\>'
    let l:curpos= getpos('.')

    let l:prev= searchpos(l:definition_pattern, 'bW')
    let l:prev_word= expand('<cWORD>')
    call setpos('.', l:curpos)

    let l:ahead= searchpos(l:definition_pattern, 'W')
    let l:ahead_word= expand('<cWORD>')
    call setpos('.', l:curpos)

    if l:prev ==# [0, 0] || l:ahead ==# [0, 0]
        if l:prev !=# [0, 0]
            return l:prev_word
        elseif l:ahead !=# [0, 0]
            return l:ahead_word
        else
            return ''
        endif
    elseif abs(l:prev[0] - line('.')) > abs(l:ahead[0] - line('.'))
        return l:prev_word
    else
        return l:ahead_word
    endif
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo

