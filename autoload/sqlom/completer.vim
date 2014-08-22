" The MIT License (MIT)
"
" Copyright (c) 2014 kamichidu
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
let s:save_cpo= &cpo
set cpo&vim

let s:V= vital#of('sqlom')
let s:L= s:V.import('Data.List')
unlet s:V

let s:completer= {}

function! s:completer.apply(context)
    if sqlom#util#in_comment([line('.'), col('.')])
        return []
    endif

    let dsn= sqlom#util#get_dsn([1, 5])

    if dsn !~# '\<dbname\s*=\s*\w\+'
        return []
    endif

    try
        let C= vdbc#connect_by_dsn(dsn)
        let candidates= []

        if s:L.has(a:context.candidate_kinds, 'table')
            let tables= C.tables({
            \   'table': a:context.incomplete . '%',
            \})

            let candidates+= map(tables, "
            \   {
            \       'word': v:val.name,
            \       'menu': v:val.remarks,
            \       'kind': 't',
            \       'dup':  1,
            \   }
            \")
        endif
        if s:L.has(a:context.candidate_kinds, 'column')
            let table_name= s:resolve_alias(a:context.precending)
            let columns= C.columns({
            \   'table': table_name,
            \   'column': a:context.incomplete . '%',
            \})

            let candidates+= map(columns, "
            \   {
            \       'word': v:val.name,
            \       'menu': v:val.remarks . '(' . v:val.table . ')',
            \       'kind': 'c',
            \       'dup':  1,
            \   }
            \")
        endif

        return candidates
    catch
        throw printf("sqlom: An error occurred `%s'", v:exception)
    finally
        if exists('C')
            call C.disconnect()
        endif
    endtry
endfunction

function! s:resolve_alias(alias)
    let definition_pattern= '\<[a-zA-Z0-9-_]\+\s\+\(as\s\+\)\=' . a:alias . '\>'
    let curpos= getpos('.')

    let prev= searchpos(definition_pattern, 'bW')
    let prev_word= expand('<cWORD>')
    call setpos('.', curpos)

    let ahead= searchpos(definition_pattern, 'W')
    let ahead_word= expand('<cWORD>')
    call setpos('.', curpos)

    if prev ==# [0, 0] || ahead ==# [0, 0]
        if prev !=# [0, 0]
            return prev_word
        elseif ahead !=# [0, 0]
            return ahead_word
        else
            return ''
        endif
    elseif abs(prev[0] - line('.')) > abs(ahead[0] - line('.'))
        return prev_word
    else
        return ahead_word
    endif
endfunction

function! sqlom#completer#new()
    return deepcopy(s:completer)
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
