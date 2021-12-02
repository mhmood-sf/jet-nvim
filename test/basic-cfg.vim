set showmatch              " Show matching brackets
set ignorecase             " Case insensitive matching
set hlsearch               " Highlight search results
set tabstop=4              " Number of columns occupied by a tab character
set softtabstop=4          " Set multiple spaces as tabstops
set expandtab              " Converts tabs to whitespace
set shiftwidth=4           " Width for autoindents
set autoindent             " Indent new line the same as the last line
set number                 " Add line numbers
set ruler                  " Show cursor position in default statusline
set cc=80                  " Set color column for cleaner code
set wildmode=longest,list  " Get bash-like tab completions
set termguicolors          " Use 24-bit RGB colors (see :help tgc)
set cursorline             " Highlight current line
set notitle                " Do not set terminal title
set nowrap                 " Do not wrap lines by default
filetype plugin indent on  " Allow autoindenting depending on filetype
syntax on                  " Syntax highlighting
execute "set packpath=" . expand("%:p:h") . "/test/"

let g:jet_packpath = expand("%:p:h") . "/test/"

lua require "lua/jet"

function! s:runtest(n)
    execute "lua require'test/test" . a:n . "'.prep()"
    execute "lua require'test/test" . a:n . "'.run()"
endfunction

command -nargs=1 Test call s:runtest(<f-args>)

