--- Jet

local fn = vim.fn

local log = require "jet.log"
local buf = require "jet.buf"
local git = require "jet.git"

local helper = require("jet.helpers")
local mk_path = helper.mk_path
local find_plugin = helper.find_plugin

-- Path to pack dir.
local PACK_DIR = vim.g.jet_pack_dir or (fn.stdpath("data") .. "/site/pack/")

local registry = require("jet.plugin").registry
local is_optsynced = require("jet.plugin").is_optsynced

-- Spawns git process to install missing plugins.
-- If optional `pack` arg is given, only missing
-- plugins from that pack will be installed.
local function install_plugins(pack)
    buf.clear()
    buf.write("", "Install", "-------")

    local installed = 0
    for _, plugin in ipairs(registry) do
        if pack == nil or plugin.pack == pack then
            if is_optsynced(plugin) == -1 then
                git.clone(plugin)
                installed = installed + 1
            end
        end
    end

    if installed == 0 then buf.write("Nothing to install!") end

    log.flush()
end

-- Spawns git process to update each plugin.
-- If optional `pack` arg is given, only plugins
-- from that pack will be installed.
local function update_plugins(pack)
    buf.clear()
    buf.write("", "Update", "------")

    for _, plugin in ipairs(registry) do
        if not pack or plugin.pack == pack then
            git.pull(plugin)
        end
    end

    log.flush()
end

-- Log which plugins are installed/missing.
local function plugin_status()
    buf.clear()
    buf.write("", "Plugins", "-------")

    local prev_pack = ""
    for _, plugin in ipairs(registry) do
        if plugin.pack ~= prev_pack then
            buf.write("")
            prev_pack = plugin.pack
        end

        local is_installed = is_optsynced(plugin) ~= -1
        local id = plugin.pack .. ":" .. plugin.name
        if not is_installed then
            buf.write_to(id, "missing!")
        else
            local msg = plugin._loaded and "loaded" or "installed, not loaded"
            buf.write_to(id, msg)
        end
    end

    log.flush()
end

-- Returns list of dirs for unused plugins in `dir`.
local function get_unused_plugin_dirs(dir)
    local unused = {}
    -- Make sure the dir exists first.
    if fn.isdirectory(dir) ~= 0 then
        -- Get all plugins installed on filesystem.
        local fs_plugins = fn.readdir(dir)
        for _, fs_plugin in ipairs(fs_plugins) do
            -- Check if they are in the registry.
            local found = find_plugin(fs_plugin, registry)
            -- If not, then append their path to unused plugins list.
            if found == nil then
                table.insert(unused, dir .. fs_plugin)
            end
        end
    end
    return unused
end

-- Cleans unused packs/plugins from PACK_DIR
local function clean_plugins()
    buf.clear()
    buf.write("", "Clean", "-----")

    -- List of dirs for unused plugins.
    local unused = {}
    -- Get packs installed on filesystem.
    local fs_packs = fn.readdir(PACK_DIR)

    -- First get dirs for unused plugins.
    for _, fs_pack in ipairs(fs_packs) do
        -- Check both opt and start dirs.
        local optpath = mk_path(fs_pack, "opt")
        local startpath = mk_path(fs_pack, "start")
        vim.list_extend(unused, get_unused_plugin_dirs(optpath))
        vim.list_extend(unused, get_unused_plugin_dirs(startpath))
    end

    -- Finish if no unused plugins found.
    if #unused == 0 then
        buf.write("No unused plugins found.")
        return
    end

    -- Log unused plugin paths.
    buf.write("Unused plugins found:", "")
    for _, path in ipairs(unused) do buf.write(path) end

    -- Use prompt buffer to confirm before proceeding.
    vim.bo.buftype = "prompt"
    -- Allow modifying buffer for prompt response.
    vim.opt_local.modifiable = true
    -- Set prompt and start insert mode for user's response.
    fn.prompt_setprompt(fn.bufnr(), "Delete all? [y/n]: ")
    fn.execute("startinsert")

    -- Callback after user enters text to the prompt.
    fn.prompt_setcallback(fn.bufnr(), function(txt)
        -- Anything starting with y is taken as yes.
        if vim.startswith(fn.tolower(txt), "y") then
            for _, path in ipairs(unused) do fn.delete(path, "rf") end
            log.write("Removed " .. #unused .. " unused plugin(s).")
            buf.write("Removed " .. #unused .. " unused plugin(s).")
        else
            log.write("JetClean command cancelled.")
            buf.write("Cancelled.")
        end
        -- Remove callback and reset buffer.
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)

    -- In case input is interrupted.
    fn.prompt_setinterrupt(fn.bufnr(), function()
        log.write("JetClean prompt interrupted.")
        buf.write("Cancelled.")
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)

    log.flush()
end

-- Check git executable is available.
if fn.executable("git") ~= 1 then log.err(20) end

-- Editor commands.
vim.cmd([[
    command -nargs=0 JetLog lua vim.cmd("vsplit " .. require"jet.log".LOG_FILE)
    command -nargs=1 JetAdd lua require"jet".load(<f-args>)
    command -nargs=0 JetClean lua require"jet".clean()
    command -nargs=0 JetStatus lua require"jet".status()
    command -nargs=? JetUpdate lua require"jet".update(<f-args>)
    command -nargs=? JetInstall lua require"jet".install(<f-args>)
    command -nargs=0 JetWipeLog lua vim.fn.writefile({}, require"jet".LOG_FILE)
]])

return {
    registry = registry,
    pack     = require("jet.plugin").create_pack,
    load     = require("jet.plugin").load,
    clean    = clean_plugins,
    status   = plugin_status,
    update   = update_plugins,
    install  = install_plugins,
}
