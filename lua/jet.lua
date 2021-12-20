--- Jet

local fn = vim.fn

-- List of all plugins.
local registry = {}

-- Path to pack dir.
local pack_dir = fn.stdpath("data") .. "/site/pack/"

-- Jet logs.
local log_file = fn.stdpath("data") .. "/jet.log"

--- UTIL FUNCTIONS

-- Returns first item that evalutes
-- to true when `f` is applied.
local function list_find(list, f)
    for _, v in ipairs(list) do
        if f(v) then return v end
    end
end

-- Returns plugin matching `name`.
local function find_plugin(name)
    return list_find(registry, function(p) return p.name == name end)
end

-- Path to `pack`'s start/opt dir.
local function get_path(opt, pack)
    return pack_dir .. pack .. "/" .. opt .. "/"
end


--- ERROR HANDLING & LOGGING

-- Jet errors.
local errs = {
    [11] = "config entries must be either strings or tables.",
    [12] = "'uri' field is required for all table entries.",
    [13] = "duplicate names found! Please ensure plugins are named uniquely.",
    [20] = "'git' executable not found. Some commands may fail."
}

-- Write `str` to log file along with date & time.
local function log(str)
    local s = fn.strftime("[%Y-%b-%d | %H:%M] ") .. str
    fn.writefile({s}, log_file, "a")
end

-- Get formatted error string from error code.
local function get_err_str(code)
    return "Jet E" .. code .. ": " .. errs[code]
end

-- Logs error message with error highlighting.
local function echo_err(code)
    log(get_err_str(code))
    vim.cmd("echohl Error")
    vim.cmd("echom '" .. get_err_str(code) .. "'")
    vim.cmd("echohl None")
end


--- JET BUFFER

-- Sets window/buffer options
-- and header for the jet buffer.
local function prep_jet_buf()
    vim.cmd("setfiletype Jet")

    vim.bo.bufhidden = "hide"
    vim.bo.buftype = "nofile"
    vim.bo.swapfile = false
    vim.bo.buflisted = false
    vim.bo.syntax = "markdown"
    vim.wo.statusline = "%= Jet %="

    fn.setline(1, "# Jet")
    fn.setline(2, "")
end

-- Opens a custom buffer for Jet.
local function open_jet_buf()
    local winnr = fn.bufwinnr("Jet")

    -- Return if buffer window is already open.
    if winnr == fn.winnr() then
        return
    elseif winnr < 0 then
        -- First, store if the buffer already existed.
        local existed = fn.bufnr("Jet") ~= -1
        -- Get the bufnr, creating it if it didn't already exist.
        local bufnr = fn.bufnr("Jet", 1)
        -- Open a window and load the buffer.
        vim.cmd("vertical topleft new | b" .. bufnr)
        -- Prepare buffer if new one was created.
        if not existed then
            prep_jet_buf()
        end
    else
        -- If buf window was already open, switch to it.
        fn.execute(winnr .. "wincmd w")
    end
end


--- LOGGING

-- Logs to the custom Jet buffer. Takes
-- multiple args, each logged to a new line.
local function log(...)
    open_jet_buf()
    vim.opt_local.modifiable = true
    for _, val in ipairs({ ... }) do
        fn.append(fn.line("$"), val)
    end
    vim.opt_local.modifiable = false
end

-- Remember line numbers for logs.
local log_lines = {}
local log_file = fn.tempname()

-- Logs to a fixed line, based on it's id.
local function log_to(id, text)
    open_jet_buf()
    vim.opt_local.modifiable = true

    local str = "<" .. id .. "> " .. text
    local line_nr = log_lines[id]

    if line_nr == nil then
        -- Get the last line of the buffer.
        line_nr = fn.line("$")
        -- Store the line nr + 1, since append
        -- writes to the line below.
        log_lines[id] = line_nr + 1
        fn.append(line_nr, str)
    else
        fn.setline(line_nr, str)
    end

    vim.opt_local.modifiable = false
    fn.writefile({str}, log_file, "a")
end

-- Clear previous contents of Jet buf
-- and reset log_lines.
local function clear_jet_buf()
    open_jet_buf()
    vim.opt_local.modifiable = true
    fn.deletebufline("Jet", 2, fn.line("$"))
    vim.opt_local.modifiable = false
    log_lines = {}
end


--- OPTSYNCING

-- Check if a plugin is optsynced. We consider a plugin
-- optsynced if its .git/HEAD file is readable in the
-- directory specified by `plugin.dir`. If .git/HEAD is
-- readable in either the <pack>/start/<plugin> or
-- <pack>/opt/<plugin> dir, we consider it installed but not
-- optsynced. This function returns 1 for optsynced, 0 for
-- installed, and -1 otherwise.
local function is_optsynced(plugin)
    local found_synced = io.open(plugin.dir .. "/.git/HEAD", "r")
    if found_synced then
        io.close(found_synced)
        return 1
    end

    local alt_dir  = plugin.opt and "start" or "opt"
    local alt_path = get_path(alt_dir, plugin.pack) .. plugin.name
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
local function optsync_plugin(plugin)
    log("Optsyncing plugin: " .. plugin.name)
    local sync_status = is_optsynced(plugin)

    if sync_status == 1 then
        return true
    elseif sync_status == 0 then
        -- If it's an opt plugin, rename from startpath to
        -- current dir (i.e optpath), otherwise vice versa.
        if plugin.opt then
            local old = get_path("start", plugin.pack) .. plugin.name
            fn.mkdir(plugin.dir, "p")
            os.rename(old, plugin.dir)
        else
            local old = get_path("opt", plugin.pack) .. plugin.name
            fn.mkdir(plugin.dir, "p")
            os.rename(old, plugin.dir)
        end
        return true
    else
        return false
    end
end


--- PLUGIN-RELATED UTILS

-- Returns plugin name if provided by user,
-- otherwise obtains name from plugin uri.
local function get_plugin_name(plugin)
    if type(plugin) == "string" then
        -- Ignore .git extension at the end of the uri.
        local has_ext = string.match(plugin, "%.git$")
        local pat = has_ext and ".*/(.*).git$" or ".*/(.*)$"
        return string.match(plugin, pat)
    end

    -- If name isn't provided, recurse and use the uri.
    return plugin.name and plugin.name or get_plugin_name(plugin.uri)
end

-- Returns git process flags if provided by user,
-- otherwise the defaults.
local function get_plugin_flags(plugin)
    if type(plugin) == "string" or plugin.flags == nil then
        return { "--depth", "1" }
    end
    return plugin.flags
end

-- Loads a specific plugin and runs it's cfg function.
-- `plugin` can be plugin name or object.
local function load_plugin(plugin)
    local is_name = type(plugin) == "string"
    local plugin_data = is_name and find_plugin(plugin) or plugin
    if plugin_data then
        log("Loading plugin: " .. plugin.name)
        vim.cmd("packadd " .. plugin_data.name)
        plugin_data._loaded = true
        if plugin_data.cfg then plugin_data.cfg() end
    end
end


--- LAZY LOADING

-- Initializes plugin's lazy loading autocmd.
local function init_lazy_load(plugin)
    if plugin.on then
        local grp = "JetLazyLoad"
        local evt = table.concat(plugin.on, ",")
        local pat = plugin.pat and table.concat(plugin.pat, ",") or "*"

        local subcmd = "lua require'jet'.load('" .. plugin.name .. "')"
        local cmdlist = {"au", grp, evt, pat, "++once", subcmd}
        local autocmd = table.concat(cmdlist, " ")

        log("Registering autocmd: " .. autocmd)
        vim.cmd("augroup JetLazyLoad")
        vim.cmd(autocmd)
    end
end


--- INIT PACK/PLUGIN

-- Initialize a plugin object, and
-- store it in the registry.
local function init_plugin(pack, data)
    local name  = get_plugin_name(data)
    local flags = get_plugin_flags(data)
    local uri   = (type(data) == "string") and data or data.uri
    local opt   = (type(data.opt) == "nil") and false or data.opt
    local dir   = pack_dir .. pack .. (opt and "/opt/" or "/start/") .. name

    log("Initialized plugin data for: " .. name)
    return {
        name    = name,
        pack    = pack,
        flags   = flags,
        uri     = uri,
        opt     = opt,
        dir     = dir,
        on      = data.on,
        pat     = data.pat,
        cfg     = data.cfg,
        _loaded = false
    }
end

-- Returns a function that takes a list of plugin configs,
-- adds them to the registry and initializes them.
local function init_pack(pack)
    return function(list)
        log("Initializing pack: " .. pack)
        for _, data in ipairs(list) do
            local data_t = type(data)
            -- Ensure pack entry is a table or string.
            if data_t ~= "string" and data_t ~= "table" then
                return echo_err(11)
            -- Ensure a uri is available.
            elseif data_t == "table" and data.uri == nil then
                return echo_err(12)
            else
                local plugin = init_plugin(pack, data)
                -- Make sure there's no duplicate names.
                if find_plugin(plugin.name) ~= nil then
                    return echo_err(13)
                else
                    table.insert(registry, plugin)
                    -- Optsync all plugins on startup.
                    local optsynced = optsync_plugin(plugin)

                    if plugin.opt then
                        init_lazy_load(plugin)
                    elseif optsynced then
                        load_plugin(plugin)
                    end
                end
            end
        end
    end
end


--- GIT SPAWN

-- Store handles for easy access.
local spawned_handles = {}

-- Spawn git process to update a plugin.
local function git_spawn(subcmd, plugin, hook)
    local logid = plugin.pack .. ":" .. plugin.name
    log("Running git " .. subcmd .. " for: " .. logid)

    -- To read command output.
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    -- Wrap so that Nvim API can be called inside loop.
    local on_read = vim.schedule_wrap(function (err, data)
        if err then
            log_to(logid, err)
        elseif data then
            -- Ignore whitespace/newlines.
            local lines = string.gmatch(data, "%s*([^\r\n]*)%s*")
            for line in lines do
                -- Don't log empty lines.
                if string.match(line, "[^%s]") then
                    log_to(logid, line)
                end
            end
        end
    end)

    -- Prepare command.
    local cmdargs = { subcmd, plugin.uri, plugin.dir, "--progress" }
    local opts = {
        args = vim.list_extend(cmdargs, plugin.flags),
        detached = true,
        hide = true,
        stdio = {nil, stdout, stderr}
    }

    local on_exit = vim.schedule_wrap(function (code)
        local handle = spawned_handles[plugin.uri]
        if not handle:is_closing() then handle:close() end
        stdout:close(); stderr:close()

        if code == 0 then
            log_to(logid, "Finished.")
            if hook then hook() end
        else
            log_to(logid, "Failed. Check `:JetLog` for more info.")
        end
    end)

    -- Run command and store handle to close later.
    local handle = vim.loop.spawn("git", opts, on_exit)
    spawned_handles[plugin.uri] = handle

    -- Start reading command output.
    vim.loop.read_start(stdout, on_read)
    vim.loop.read_start(stderr, on_read)
end


--- INSTALL

-- Spawns git process to install missing plugins.
-- If optional `pack` arg is given, only missing
-- plugins from that pack will be installed.
local function install_plugins(pack)
    clear_jet_buf()
    log("", "Install", "-------")

    local installed = 0
    for _, plugin in ipairs(registry) do
        if pack == nil or plugin.pack == pack then
            if is_optsynced(plugin) == -1 then
                git_spawn("clone", plugin, function() load_plugin(plugin) end)
                installed = installed + 1
            end
        end
    end

    if installed == 0 then log("Nothing to install!") end
end


--- UPDATE

-- Spawns git process to update each plugin.
-- If optional `pack` arg is given, only plugins
-- from that pack will be installed.
local function update_plugins(pack)
    clear_jet_buf()
    log("", "Update", "------")

    for _, plugin in ipairs(registry) do
        if not pack or plugin.pack == pack then
            git_spawn("pull", plugin)
        end
    end
end


-- PLUGIN STATUS --------------------------------------------------------------

-- Log which plugins are installed/missing.
local function plugin_status()
    clear_jet_buf()
    log("", "Plugins", "-------")

    local prev_pack = ""
    for _, plugin in ipairs(registry) do
        if plugin.pack ~= prev_pack then
            log("")
            prev_pack = plugin.pack
        end

        local is_installed = is_optsynced(plugin) ~= -1
        local id = plugin.pack .. ":" .. plugin.name
        if not is_installed then
            log_to(id, "missing!")
        else
            log_to(id, plugin._loaded and "loaded" or "installed, not loaded")
        end
   end
end


--- CLEAN PLUGINS

-- Returns list of dirs for unused plugins in `dir`.
local function get_unused_dirs(dir)
    local unused = {}
    -- Make sure the dir exists first.
    if fn.isdirectory(dir) ~= 0 then
        -- Get all plugins installed on filesystem.
        local fs_plugins = fn.readdir(dir)
        for _, fs_plugin in ipairs(fs_plugins) do
            -- Check if they are in the registry.
            local found = find_plugin(fs_plugin)
            -- If not, then append their path to unused plugins list.
            if found == nil then
                table.insert(unused, dir .. fs_plugin)
            end
        end
    end
    return unused
end

-- Cleans unused packs/plugins from pack_path
local function clean_plugins()
    clear_jet_buf()
    log("", "Clean", "-----")

    -- List of dirs for unused plugins.
    local unused = {}
    -- Get packs installed on filesystem.
    local fs_packs = fn.readdir(pack_path)

    -- First get dirs for unused plugins.
    for _, fs_pack in ipairs(fs_packs) do
        -- Check both opt and start dirs.
        local optpath = get_path("opt", fs_pack)
        local startpath = get_path("start", fs_pack)
        vim.list_extend(unused, get_unused_dirs(optpath))
        vim.list_extend(unused, get_unused_dirs(startpath))
    end

    -- Finish if no unused plugins found.
    if #unused == 0 then
        log("", "No unused plugins found.")
        return
    end

    -- Log unused plugin paths.
    log("", "Unused plugins found:", "")
    for _, path in ipairs(unused) do log(path) end

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
            log("Removed " .. #unused .. " unused plugin(s).")
        else
            log("Cancelled.")
        end
        -- Remove callback and reset buffer.
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)

    -- In case input is interrupted.
    fn.prompt_setinterrupt(fn.bufnr(), function()
        log("Cancelled.")
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)
end


-- INITIALIZE -----------------------------------------------------------------

if fn.executable("git") ~= 1 then echo_err(20) end

vim.cmd([[
    command -nargs=0 JetLog     lua vim.cmd("split " .. Jet.log_file)
    command -nargs=1 JetAdd     lua Jet.load(<f-args>)
    command -nargs=0 JetClean   lua Jet.clean()
    command -nargs=0 JetStatus  lua Jet.status()
    command -nargs=? JetUpdate  lua Jet.update(<f-args>)
    command -nargs=? JetInstall lua Jet.install(<f-args>)
]])

Jet = {
    log_file = log_file,
    registry = registry,
    pack     = init_pack,
    load     = load_plugin,
    clean    = clean_plugins,
    status   = plugin_status,
    update   = update_plugins,
    install  = install_plugins,
}

