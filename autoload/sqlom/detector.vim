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

let s:detector= {}

function! s:detector.apply(context)
    if sqlom#util#in_comment([line('.'), col('.')])
        return -1
    endif

    let input= strpart(getline('.'), 0, col('.'))

    if input =~# '\.\w\+$'
        let a:context.precending= matchstr(input, '\w\+\ze\.\w\+$')
        let a:context.incomplete= matchstr(input, '\.\zs\w\+$')
        let a:context.candidate_kinds= ['column']

        return match(input, '\.\zs\w\+$')
    elseif input =~# '\w\+$'
        let a:context.precending= ''
        let a:context.incomplete= matchstr(input, '\w\+$')
        let a:context.candidate_kinds= ['table']

        return match(input, '\w\+$')
    endif

    return -1
endfunction

function! sqlom#detector#new()
    return deepcopy(s:detector)
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
