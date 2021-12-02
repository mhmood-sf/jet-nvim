local function prep()
    -- start with a clean dir
    local testpack = vim.fn.expand("%:p:h") .. "/pack/test2/"
    vim.fn.delete(testpack, "rf")

    -- TEST CONFIG with old tags
    Jet.pack "test2" {
    -- need to find plugins with old tags
    -- TODO
    }

    vim.cmd "JetInstall test2"
end

local function run()
    -- Clear registry first here.
    -- TODO

    -- TEST CONFIG without tags
    Jet.pack "test2" {

    }

    vim.cmd "JetUpdate test2"
end

return { prep = prep, run = run }

