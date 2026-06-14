" Vim syntax file
" Language: khar (stack-based scripting language)
" Maintainer: Kirdow
" Latest Revision: 2026-05-27

if exists("b:current_syntax")
  finish
endif

" Comments
syn match kharComment "\v^#.*$"

" Stack Operations
syn keyword kharStackOp s

" Output Operations
syn keyword kharOutput p P

" Operators - Arithmetic
syn match kharOperator "+"
syn match kharOperator "-"
syn match kharOperator "\*"
syn match kharOperator "/"

" Operators - String Operators
syn match kharOperator "\."

" Strings - literals
syn region kharString start='`' end='`' skip='\\`' contains=kharStringEscape
syn match kharStringEscape contained "\\[ntr\\`]"

" Numbers - literals (defined after kharString so it wins the equal-length tie)
syn match kharStringNumber "`\-\?[0-9]\+`"

" Link to standard highlighting groups
hi def link kharComment Comment
hi def link kharStackOp Function
hi def link kharOutput Statement
hi def link kharOperator Operator
hi def link kharStringNumber Number
hi def link kharString String
hi def link kharStringEscape SpecialChar

let b:current_syntax = "khar"
