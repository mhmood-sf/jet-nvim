local Jet = require"lua/jet"

local function prep()
    -- start with a clean dir
    local testpackA = vim.g.jet_pack_dir .. "/pack/test3a/"
    local testpackB = vim.g.jet_pack_dir .. "/pack/test3b/"
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
    Jet.install()
end


local function run()
    -- Clear registry.
    for i, v in ipairs(Jet.registry) do
        Jet.registry[i] = nil
    end

    -- Omit pack test3b entirely, and one plugin
    -- from test3a.
    Jet.pack "test3a" {
        { uri  = "git@github.com:quintik/qline",
          opt  = true },
    }

    Jet.clean()
end

return { prep = prep, run = run }

