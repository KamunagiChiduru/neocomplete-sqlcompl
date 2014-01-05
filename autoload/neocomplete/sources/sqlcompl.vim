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

let s:source= {
\   'name': 'sqlcompl',
\   'kind': 'manual',
\   'filetypes': {'sql': 1},
\   'hooks': {},
\}

function! neocomplete#sources#sqlcompl#define()
    return s:source
endfunction

function! s:source.hooks.on_init(context)
    echomsg 'sqlcompl server is launched!'
    call sqlcompl#launch_server()
    augroup NeocompleteSqlcompl
        autocmd!
        autocmd VimLeavePre * echomsg 'sqlcompl server is terminated!' | call sqlcompl#terminate_server()
    augroup END
endfunction

function! s:source.get_complete_position(context)
    if sqlcompl#within_comment()
        return -1
    endif
    " skip if looks like keyword
    if sqlcompl#looks_like_keyword(matchstr(a:context.input, '\w\+$'))
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

    let l:cache= get(a:context, 'source__cache', sqlcompl#cache())
    let a:context.source__cache= l:cache

    if !l:cache.has('databases')
        try
            let l:client= sqlcompl#connect()

            let l:databases= l:client.call('databases', extend({
            \   'dbtype': get(l:config, 'dbtype', 'pg'),
            \   'host':   get(l:config, 'host', 'localhost'),
            \   'port':   get(l:config, 'port', 5432),
            \   'dbname': l:config.dbname,
            \   'username': get(l:config, 'username', 'postgres'),
            \   'password': get(l:config, 'password', 'postgres'),
            \}, {}))

            call l:cache.set('databases', l:databases)
        catch /.*/
            echoerr 'sqlcompl: caught an exception ... ' . v:exception
        finally
            if exists('l:client')
                call l:client.close()
            endif
        endtry
    endif
    if !s:L.has(map(copy(l:cache.get('databases')), 'v:val.name'), l:config.dbname)
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

    let l:method_parameters= extend({
    \   'dbtype': get(l:config, 'dbtype', 'pg'),
    \   'host':   get(l:config, 'host', 'localhost'),
    \   'port':   get(l:config, 'port', 5432),
    \   'dbname': l:config.dbname,
    \   'username': get(l:config, 'username', 'postgres'),
    \   'password': get(l:config, 'password', 'postgres'),
    \}, l:analinfo)
    let l:cache_key= l:method . '/' . string(l:method_parameters)
    if l:cache.has(l:cache_key)
        let l:candidates= l:cache.get(l:cache_key)
    else
        try
            let l:client= sqlcompl#connect()

            let l:candidates= l:client.call(l:method, l:method_parameters)

            if !empty(l:candidates)
                call l:cache.set(l:cache_key, l:candidates)
            endif
        catch /.*/
            echoerr 'sqlcompl: caught an exception ... ' . v:exception
        finally
            if exists('l:client')
                call l:client.close()
            endif
        endtry
    endif

    return map(deepcopy(l:candidates), 's:new_candidate(v:val)')
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

