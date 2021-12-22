--- Jet

local fn = vim.fn
local uv = vim.loop

-- List of all plugin tables.
local registry = {}
-- Path to pack dir.
local PACK_DIR = vim.g.jet_pack_dir or (fn.stdpath("data") .. "/site/pack/")
-- LOG_FILE path and handle. We'll open the file just once,
-- flush after every editor command, and close on VimLeavePre.
local LOG_FILE = fn.stdpath("data") .. "/jet.log"
local log_handle = io.open(LOG_FILE, "a")

--[
--- ERROR HANDLING & LOGGING
--]

-- Jet errors.
local errs = {
    [11] = "config entries must be either strings or tables.",
    [12] = "'uri' field is required for all table entries.",
    [13] = "duplicate names found! Please ensure plugins are named uniquely.",
    [20] = "'git' executable not found. Some commands may fail.",
    [30] = "unable to open log file (" .. LOG_FILE .. ")"
}

-- Write `msg` to log file along with timestamp.
local function log_write(msg)
    -- Make sure log_handle is available.
    if log_handle ~= nil then
        local str = os.date("[%Y-%b-%d | %H:%M] ") .. msg
        log_handle:write(str)
    end
end

-- Executes pending writes to a file.
local function log_flush()
    if log_handle ~= nil then
        log_handle:flush()
    end
end

-- Get formatted error string from error code.
local function get_err_str(code)
    return "Jet E" .. code .. ": " .. errs[code]
end

-- Echoes error message (from the given `code`).
-- Flush logs here since echo_err may be executed outside
-- of functions ran by editor commands.
local function echo_err(code)
    log_write(get_err_str(code))

    vim.cmd("echohl Error")
    vim.cmd("echom '" .. get_err_str(code) .. "'")
    vim.cmd("echohl None")

    log_flush()
end

--[
--- JET BUFFER
--]

-- Sets window/buffer options and header.
local function prep_jet_buf()
    log_write("Preparing Jet Buffer.")
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

-- Opens window for custom Jet buffer.
local function open_jet_win()
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

-- Writes each arg as a line to the custom buffer.
local function jet_buf_write(...)
    open_jet_win()
    vim.opt_local.modifiable = true
    for _, val in ipairs({ ... }) do
        fn.append(fn.line("$"), val)
    end
    vim.opt_local.modifiable = false
end

-- Remember line numbers for logs.
local line_ids = {}

-- Logs to a fixed line, based on it's id.
local function jet_buf_write_to(id, text)
    open_jet_win()
    vim.opt_local.modifiable = true

    local str = "<" .. id .. "> " .. text
    local line_nr = line_ids[id]

    if line_nr == nil then
        -- Get the last line of the buffer.
        line_nr = fn.line("$")
        -- Store the line_nr + 1, since append
        -- writes to the line below.
        line_ids[id] = line_nr + 1
        fn.append(line_nr, str)
    else
        fn.setline(line_nr, str)
    end

    vim.opt_local.modifiable = false
end

-- Clear contents of custom buffer and reset line_ids.
local function clear_jet_buf()
    open_jet_win()
    vim.opt_local.modifiable = true
    fn.deletebufline("Jet", 2, fn.line("$"))
    vim.opt_local.modifiable = false
    line_ids = {}
end

--[
--- UTILITY FUNCTIONS
--]

-- Returns plugin with the specified `name`.
-- This is also why we can't allow plugins with the same name :/
local function find_plugin(name)
    for _, plugin in ipairs(registry) do
        if plugin.name == name then
            return plugin
        end
    end
end

-- Concatenates args after PACK_DIR to construct the
-- path to a pack's opt/start dir or a plugin dir.
-- Basically returns "<PACK_DIR>/<pack>/<opt>/<plugin?>".
-- The `plugin` arg is optional.
local function mk_path(pack, opt, plugin)
    return PACK_DIR .. pack .. "/" .. opt .. "/" .. (plugin or "")
end

--[
--- OPTSYNCING
--]

-- Check if a plugin is optsynced. We consider a plugin
-- optsynced if its .git/HEAD file is readable in the
-- directory specified by `plugin.dir`. If .git/HEAD is
-- readable in either the <pack>/start/<plugin> or
-- <pack>/opt/<plugin> dir, we consider it installed but not
-- optsynced. This function returns 1 for optsynced, 0 for
-- installed, and -1 otherwise (considered missing).
local function is_optsynced(plugin)
    log_write("Checking is_optsynced for: " .. plugin.name)
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
local function optsync_plugin(plugin)
    log_write("Optsyncing plugin: " .. plugin.name)
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

--[
--- PLUGIN-RELATED UTILS / LAZY-LOADING
--]

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

-- Returns git process args if provided by user,
-- otherwise the defaults.
local function get_plugin_args(plugin)
    if type(plugin) == "string" or plugin.git == nil then
        -- See: https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/
        -- Shallow clones will still download the entire history
        -- when updating, so we use partial clones to avoid that.
        return { "--filter=blob:none" }
    end
    return plugin.git
end

-- Loads a specific plugin and runs it's cfg function.
-- `plugin` can be plugin name or table.
local function load_plugin(arg)
    local is_name = type(arg) == "string"
    local plugin = is_name and find_plugin(arg) or arg
    if plugin then
        log_write("Loading plugin: " .. plugin.name)
        vim.cmd("packadd " .. plugin.name)
        plugin._loaded = true
        if plugin.cfg then plugin.cfg() end
    end

    log_flush()
end

-- Initializes plugin's lazy loading autocmd(s).
local function init_lazy_load(plugin)
    if type(plugin.on) == "table" then
        vim.cmd "augroup JetLazyLoad"
        for _, evtpat in ipairs(plugin.on) do
            local luafn = "lua require'jet'.load('" .. plugin.name .. "')"
            local args  = { "autocmd", "JetLazyLoad", evtpat, "++once", luafn }
            local aucmd = table.concat(args, " ")

            log_write("Registering autocmd: " .. aucmd)
            vim.cmd(aucmd)
        end
        vim.cmd "augroup END"
    end
end

--[
--- INITIALIZE PACK/PLUGIN
--]

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
local function init_pack(pack)
    return function(list)
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

                    -- Set up lazy load if opt, otherwise load plugin.
                    -- Note this means that plugins are loaded whenever
                    -- the Jet config is executed by Vim, and not after
                    -- init.vim has been processed (which is the default
                    -- behaviour).
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

--[
--- GIT PROCESS
--]

-- Spawns git process and handles opening/closing
-- the process/pipes/etc.
local function git_spawn(args, on_read, on_exit)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    -- Note we use PACK_DIR as the cwd.
    local opts = {
        args  = args,
        cwd   = PACK_DIR,
        stdio = { nil, stdout, stderr }
    }

    -- Declare vars so we can close them in the exit callback.
    local handle, pid
    -- Spawn process with opts and exit callback.
    -- Also wrap callback in case on_exit invokes Nvim API.
    -- (otherwise, API functions are not allowed in event loop.)
    handle, pid = uv.spawn("git", opts, vim.schedule_wrap(function(code)
        if not handle:is_closing() then handle:close() end
        stdout:close(); stderr:close()
        log_write("Closed pid: " .. pid .. ", code: " .. code)
        on_exit(code)
    end))

    -- Start reading stdout. Again, wrap callback in case Nvim API
    -- is invoked.
    stdout:read_start(vim.schedule_wrap(function(error, data)
        if error then log_write(error) end
        if data then log_write(data); on_read(data) end
    end))

    -- Start reading stderr. Just write output to log file.
    stderr:read_start(function(error, data)
        if error then log_write(error) elseif data then log_write(data) end
    end)

    log_write("Spawned new git process with pid: " .. pid)
end

-- Returns the `on_read` callback for stdout pipe.
local function git_on_read(logid)
    return function(data)
        -- Ignore whitespace/newlines.
        local lines = string.gmatch(data, "%s*([^\r\n]*)%s*")
        for line in lines do
            -- Only write non-empty lines.
            if string.match(line, "[^%s]") then
                jet_buf_write_to(logid, line)
            end
        end
    end
end

-- Returns the `on_exit` callback for process handle.
-- Writes success/fail msg to jet_buf with given logid,
-- and calls hook when command finishes successfully.
local function git_on_exit(logid, hook)
    return function(code)
        -- Call hook if finished successfully.
        if code == 0 then
            jet_buf_write_to(logid, "Finished.")
            hook()
        else
            jet_buf_write_to(logid, "Failed. Check `:JetLog` for more info.")
        end
    end
end

-- Installs given plugin by running git clone.
-- Note that we initially install every plugin into the optpath.
-- The hook then `:packadd`s the start plugins after installation
-- (this is because `:packadd` only searches opt dirs, so installing
-- them into startpath and then loading them manually would require
-- extra work like sourcing all the files and adding paths to
-- runtimepath etc.) Later when nvim is started the plugins are
-- optsynced so everything will be eventually consistent.
local function git_clone(plugin)
    local logid = plugin.pack .. ":" .. plugin.name
    log_write("Running git clone for: <" .. logid .. ">")

    -- Include plugin args and use optpath for installing.
    local args = { "clone", "--progress" }
    local optpath = mk_path(plugin.pack, "opt", plugin.name)
    vim.list_extend(args, plugin.args)
    vim.list_extend(args, { plugin.uri, optpath })

    -- Note plugin.run is called after installation but before
    -- the plugin is loaded (if its a start plugin)!
    local hook = function()
        if plugin.run then plugin.run("install") end
        if not plugin.opt then load_plugin(plugin) end
    end

    local on_read = git_on_read(logid)
    local on_exit = git_on_exit(logid, hook)
    git_spawn(args, on_read, on_exit)
end

-- Updates plugins by running git pull.
local function git_pull(plugin)
    local logid = plugin.pack .. ":" .. plugin.name
    log_write("Running git pull for: <" .. logid .. ">")

    -- Note that we only call `git pull`, so we assume there is
    -- an upstream branch.
    local args = { "pull", "--progress" }

    local hook = function() if plugin.run then plugin.run("update") end end

    local on_read = git_on_read(logid)
    local on_exit = git_on_exit(logid, hook)
    git_spawn(args, on_read, on_exit)
end

--[
--- INSTALL & UPDATE PLUGINS
--]

-- Spawns git process to install missing plugins.
-- If optional `pack` arg is given, only missing
-- plugins from that pack will be installed.
local function install_plugins(pack)
    clear_jet_buf()
    jet_buf_write("", "Install", "-------")

    local installed = 0
    for _, plugin in ipairs(registry) do
        if pack == nil or plugin.pack == pack then
            if is_optsynced(plugin) == -1 then
                git_clone(plugin)
                installed = installed + 1
            end
        end
    end

    if installed == 0 then jet_buf_write("Nothing to install!") end

    log_flush()
end

-- Spawns git process to update each plugin.
-- If optional `pack` arg is given, only plugins
-- from that pack will be installed.
local function update_plugins(pack)
    clear_jet_buf()
    jet_buf_write("", "Update", "------")

    for _, plugin in ipairs(registry) do
        if not pack or plugin.pack == pack then
            git_pull(plugin)
        end
    end

    log_flush()
end

--[
--- PLUGIN STATUS
--]

-- Log which plugins are installed/missing.
local function plugin_status()
    clear_jet_buf()
    jet_buf_write("", "Plugins", "-------")

    local prev_pack = ""
    for _, plugin in ipairs(registry) do
        if plugin.pack ~= prev_pack then
            jet_buf_write("")
            prev_pack = plugin.pack
        end

        local is_installed = is_optsynced(plugin) ~= -1
        local id = plugin.pack .. ":" .. plugin.name
        if not is_installed then
            jet_buf_write_to(id, "missing!")
        else
            local msg = plugin._loaded and "loaded" or "installed, not loaded"
            jet_buf_write_to(id, msg)
        end
    end

    log_flush()
end

--[
--- CLEAN PLUGINS
--]

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

-- Cleans unused packs/plugins from PACK_DIR
local function clean_plugins()
    clear_jet_buf()
    jet_buf_write("", "Clean", "-----")

    -- List of dirs for unused plugins.
    local unused = {}
    -- Get packs installed on filesystem.
    local fs_packs = fn.readdir(PACK_DIR)

    -- First get dirs for unused plugins.
    for _, fs_pack in ipairs(fs_packs) do
        -- Check both opt and start dirs.
        local optpath = mk_path(fs_pack, "opt")
        local startpath = mk_path(fs_pack, "start")
        vim.list_extend(unused, get_unused_dirs(optpath))
        vim.list_extend(unused, get_unused_dirs(startpath))
    end

    -- Finish if no unused plugins found.
    if #unused == 0 then
        jet_buf_write("No unused plugins found.")
        return
    end

    -- Log unused plugin paths.
    jet_buf_write("Unused plugins found:", "")
    for _, path in ipairs(unused) do jet_buf_write(path) end

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
            log_write("Removed " .. #unused .. " unused plugin(s).")
            jet_buf_write("Removed " .. #unused .. " unused plugin(s).")
        else
            log_write("JetClean command cancelled.")
            jet_buf_write("Cancelled.")
        end
        -- Remove callback and reset buffer.
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)

    -- In case input is interrupted.
    fn.prompt_setinterrupt(fn.bufnr(), function()
        log_write("JetClean prompt interrupted.")
        jet_buf_write("Cancelled.")
        fn.prompt_setcallback(fn.bufnr(), "")
        vim.bo.buftype = "nofile"
        vim.opt_local.modifiable = false
    end)

    log_flush()
end

--[
--- INITIALIZE
--]

-- Check git executable is available.
if fn.executable("git") ~= 1 then echo_err(20) end
-- Clear log file if larger than 500KB
if fn.getfsize(LOG_FILE) >= 500000 then fn.writefile({}, LOG_FILE) end
-- Notify user if unable to open log file, otherwise
-- register autocmd for closing file on exit.
if log_handle == nil then
    echo_err(30)
else
    vim.cmd "autocmd VimLeavePre * lua require'jet'.log_handle:close()"
end

-- Editor commands.
vim.cmd([[
    command -nargs=0 JetLog lua vim.cmd("vsplit " .. require'jet'.LOG_FILE)
    command -nargs=1 JetAdd lua require'jet'.load(<f-args>)
    command -nargs=0 JetClean lua require'jet'.clean()
    command -nargs=0 JetStatus lua require'jet'.status()
    command -nargs=? JetUpdate lua require'jet'.update(<f-args>)
    command -nargs=? JetInstall lua require'jet'.install(<f-args>)
    command -nargs=0 JetWipeLog lua vim.fn.writefile({}, require'jet'.LOG_FILE)
]])

return {
    LOG_FILE = LOG_FILE,
    registry = registry,
    pack     = init_pack,
    load     = load_plugin,
    clean    = clean_plugins,
    status   = plugin_status,
    update   = update_plugins,
    install  = install_plugins,
}

