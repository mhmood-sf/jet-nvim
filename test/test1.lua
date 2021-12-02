local function prep()
    -- start with a clean dir
    local testpack = vim.g.jet_packpath .. "/pack/test1/"
    vim.fn.delete(testpack, "rf")

    -- TEST CONFIG
    local scrollbarcfg = [[
    augroup ScrollbarInit
        autocmd!
        autocmd WinScrolled,VimResized,QuitPre * silent! lua require"scrollbar".show()
        autocmd WinEnter,FocusGained           * silent! lua require"scrollbar".show()
        autocmd WinLeave,BufLeave,BufWinLeave,FocusLost * silent! lua require"scrollbar".clear()
    augroup end ]]

    Jet.pack "test1" {
        { uri  = "git@github.com:quintik/qline",
          opt  = true },

        { name = "snipsnipsnip",
          uri  = "git@github.com:quintik/Snip",
          opt  = true },

        { uri   = "git@github.com:norcalli/nvim-colorizer.lua",
          name  = "colorizer",
          flags = { "--depth", "1", "--branch", "color-editor" },
          cfg   = function() require"colorizer".setup() end },

        { uri = "git@github.com:preservim/nerdtree",
          opt = true, 
          on  = { "CmdUndefined" },
          pat = { "NERDTree" } },

        { uri = "git@github.com:Xuyuanp/scrollbar.nvim",
          opt = true,
          on  = { "WinEnter" },
          cfg = function() vim.cmd(scrollbarcfg) end }
    }
end

local function run()
    vim.cmd "JetInstall test1"
end

return { prep = prep, run = run }

