local fn = vim.fn

local log = require "jet.log"

local helper = require("jet.helpers")
local mk_path = helper.mk_path
local find_plugin = helper.find_plugin
local get_plugin_args = helper.get_plugin_args
local get_plugin_name = helper.get_plugin_name

-- List of all plugin tables.
local registry = {}

-- Check if a plugin is optsynced. We consider a plugin
-- optsynced if its .git/HEAD file is readable in the
-- directory specified by `plugin.dir`. If .git/HEAD is
-- readable in either the <pack>/start/<plugin> or
-- <pack>/opt/<plugin> dir, we consider it installed but not
-- optsynced. This function returns 1 for optsynced, 0 for
-- installed, and -1 otherwise (considered missing).
-- NOTE that if a plugin directory is not a git repository,
-- then the plugin is ALSO considered missing, even if it is
-- technically optsynced. Ensure there is a git repository
-- in each plugin directory.
local function is_optsynced(plugin)
    log.write("Checking is_optsynced for: " .. plugin.name)
    -- Check it's actual directory.
    local found_synced = io.open(plugin.dir .. "/.git/HEAD", "r")
    if found_synced then
        io.close(found_synced)
        return 1
    end

    -- Check the other directory.
    local alt_dir  = plugin.opt and "start" or "opt"
    local alt_path = mk_path(plugin.pack, alt_dir, plugin.name)
    local found_installed = io.open(alt_path .. "/.git/HEAD", "r")
    if found_installed then
        io.close(found_installed)
        return 0
    end

    return -1
end

-- Sync a plugin to it's appropriate opt/start
-- directory. Returns true if synced successfully,
-- otherwise false (meaning plugin is not installed).
local function optsync(plugin)
    log.write("Optsyncing plugin: " .. plugin.name)
    local sync_status = is_optsynced(plugin)

    if sync_status == 1 then
        return true
    elseif sync_status == 0 then
        -- If it's an opt plugin, rename from startpath to
        -- current dir (i.e optpath), otherwise vice versa.
        if plugin.opt then
            local old = mk_path(plugin.pack, "start", plugin.name)
            fn.mkdir(plugin.dir, "p")
            os.rename(old, plugin.dir)
        else
            local old = mk_path(plugin.pack, "opt", plugin.name)
            fn.mkdir(plugin.dir, "p")
            os.rename(old, plugin.dir)
        end
        return true
    else
        return false
    end
end

-- Loads a specific plugin and runs it's cfg function.
-- `plugin` can be plugin name or table.
local function load_plugin(arg)
    local is_name = type(arg) == "string"
    local plugin = is_name and find_plugin(arg, registry) or arg
    if plugin then
        log.write("Loading plugin: " .. plugin.name)
        vim.cmd("packadd " .. plugin.name)
        plugin._loaded = true
        if plugin.cfg then plugin.cfg() end
    end

    log.flush()
end

-- Initializes plugin's lazy loading autocmd(s).
local function make_lazy(plugin)
    if type(plugin.on) == "table" then
        vim.cmd "augroup JetLazyLoad"
        for _, evtpat in ipairs(plugin.on) do
            local luafn = "lua require'jet.plugin'.load('" .. plugin.name .. "')"
            local args  = { "autocmd", "JetLazyLoad", evtpat, "++once", luafn }
            local aucmd = table.concat(args, " ")

            log.write("Registering autocmd: " .. aucmd)
            vim.cmd(aucmd)
        end
        vim.cmd "augroup END"
    end
end

-- Initialize a plugin object, and
-- store it in the registry.
local function init_plugin(pack, data)
    local name  = get_plugin_name(data)
    local args  = get_plugin_args(data)
    local uri   = (type(data) == "string") and data or data.uri
    local opt   = (type(data.opt) == "nil") and false or data.opt
    local dir   = mk_path(pack, opt and "/opt/" or "/start/", name)

    return {
        name    = name,
        pack    = pack,
        args    = args,
        uri     = uri,
        opt     = opt,
        dir     = dir,
        on      = data.on,
        cfg     = data.cfg,
        run     = data.run,
        _loaded = false
    }
end

-- Returns a function that takes a list of plugin configs,
-- adds them to the registry and initializes them.
local function create_pack(pack)
    return function(list)
        for _, data in ipairs(list) do
            local data_t = type(data)
            -- Ensure pack entry is a table or string.
            if data_t ~= "string" and data_t ~= "table" then
                return log.err(11)
            -- Ensure a uri is available.
            elseif data_t == "table" and data.uri == nil then
                return log.err(12)
            else
                local plugin = init_plugin(pack, data)
                -- Make sure there's no duplicate names.
                if find_plugin(plugin.name, registry) ~= nil then
                    return log.err(13)
                else
                    table.insert(registry, plugin)
                    -- Optsync all plugins on startup.
                    local optsynced = optsync(plugin)

                    -- Set up lazy load if opt, otherwise load plugin.
                    -- Note this means that plugins are loaded whenever
                    -- the Jet config is executed by Vim, and not after
                    -- init.vim has been processed (which is the default
                    -- behaviour).
                    if plugin.opt then
                        make_lazy(plugin)
                    elseif optsynced then
                        load_plugin(plugin)
                    end
                end
            end
        end
    end
end

return {
    registry     = registry,
    init         = init_plugin,
    load         = load_plugin,
    optsync      = optsync,
    make_lazy    = make_lazy,
    create_pack  = create_pack,
    is_optsynced = is_optsynced,
}
