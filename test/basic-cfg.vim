let g:jet_pack_dir = expand("%:p:h") . "/test/pack/"

set ignorecase             " Case insensitive matching
set hlsearch               " Highlight search results
set tabstop=4              " Number of columns occupied by a tab character
set softtabstop=4          " Set multiple spaces as tabstops
set expandtab              " Converts tabs to whitespace
set shiftwidth=4           " Width for autoindents
set autoindent             " Indent new line the same as the last line
set number                 " Add line numbers
set wildmode=longest,list  " Get bash-like tab completions
set notitle                " Do not set terminal title
filetype plugin indent on  " Allow autoindenting depending on filetype
syntax on                  " Syntax highlighting

execute "set runtimepath=" . expand("%:p:h")

execute "set packpath=" . g:jet_pack_dir


lua require "lua/jet"
function! s:runtest(n)
    execute "lua require'test/test" . a:n . "'.prep()"
    execute "lua require'test/test" . a:n . "'.run()"
endfunction
command -nargs=1 Test call s:runtest(<f-args>)

" Redefine Jet commands to fix the requires (lua/jet instead of just jet)
command! -nargs=0 JetLog lua vim.cmd("vsplit " .. require'jet'.LOG_FILE)
command! -nargs=1 JetAdd lua require'lua/jet'.load(<f-args>)
command! -nargs=0 JetClean lua require'lua/jet'.clean()
command! -nargs=0 JetStatus lua require'lua/jet'.status()
command! -nargs=? JetUpdate lua require'lua/jet'.update(<f-args>)
command! -nargs=? JetInstall lua require'lua/jet'.install(<f-args>)
command! -nargs=0 JetWipeLog lua vim.fn.writefile({}, require'lua/jet'.LOG_FILE)

