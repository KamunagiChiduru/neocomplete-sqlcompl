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

function! sqlom#util#looks_like_keyword(word, ...)
    if !exists('s:keywords')
        let s:keywords= readfile(globpath(&runtimepath, 'resources/keyword'))
    endif

    let min_length= get(a:000, 0, 2)
    let keywords= filter(copy(s:keywords), 'strlen(v:val) >= min_length')
    let pattern= '^\c\%(' . join(map(keywords, 's:make_shorthand_regex(v:val, min_length)'), '\|') . '\)$'

    return a:word =~# pattern
endfunction

function! sqlom#util#in_comment(pos)
    " synIDattr() won't work in insert mode
    let comment_start= match(getline(a:pos[0]), '--')

    if comment_start == -1
        return 0
    endif

    return comment_start <= a:pos[1]
endfunction

function! s:make_shorthand_regex(word, min_length)
    if strlen(a:word) <= a:min_length
        return a:word
    endif

    return strpart(a:word, 0, a:min_length) . '\%[' . strpart(a:word, a:min_length) . ']'
endfunction

let &cpo= s:save_cpo
unlet s:save_cpo
