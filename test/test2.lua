local Jet = require"lua/jet"

local function prep()
    -- start with a clean dir
    local testpack = vim.g.jet_pack_dir .. "test2/"
    vim.fn.delete(testpack, "rf")

    -- copy old plugins to test dir
    os.execute("mkdir " .. testpack)
    os.execute("cp " .. vim.g.jet_pack_dir .. "/pack/nvim/** " .. testpack .. " -r")
end

local function run()
    Jet.pack "test2" {
        { name = "treesitter",
          uri  = "git@github.com:nvim-treesitter/nvim-treesitter" },

        { name = "lspconfig",
          uri  = "git@github.com:neovim/nvim-lspconfig",
          opt  = true,
          on   = { "CmdUndefined" },
          pat  = { "LspStart" } }
    }

    Jet.update("test2")
end

return { prep = prep, run = run }

