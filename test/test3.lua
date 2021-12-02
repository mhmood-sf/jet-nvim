local function prep()
    -- start with a clean dir
    local testpackA = vim.fn.expand("%:p:h") .. "/pack/test3a/"
    local testpackB = vim.fn.expand("%:p:h") .. "/pack/test3b/"
    vim.fn.delete(testpackA, "rf")
    vim.fn.delete(testpackB, "rf")

    -- TEST CONFIG
    Jet.pack "test3a" {
        { uri  = "git@github.com:quintik/qline",
          opt  = true },

        { name = "snipsnipsnip",
          uri  = "git@github.com:quintik/Snip",
          opt  = true },
    }

    Jet.pack "test3b" {
        { uri  = "git@github.com:quintik/qline",
          opt  = true },

        { name = "snipsnipsnip",
          uri  = "git@github.com:quintik/Snip",
          opt  = true },
    }

    -- First install some plugins
    vim.cmd "JetInstall"
end


local function run()
    -- clear registry here
    -- TODO

    -- Omit pack test3b entirely, and one plugin
    -- from test3a.
    Jet.pack "test3a" {
        { uri  = "git@github.com:quintik/qline",
          opt  = true },
    }

    vim.cmd "JetClean"
end

return { prep = prep, run = run }

