-------------------------------------------------------------------------------
----- Jet - yet another plugin-manager ----------------------------------------
-------------------------------------------------------------------------------

-- Stores all registered plugins and their configs
local registry = {}

-- Path to pack dir
local pack_dir = ""

-- Store handles for easy access
local spawn_handles = {}

-------------------------------------------------------------------------------
----- UTIL FUNCTIONS ----------------------------------------------------------
-------------------------------------------------------------------------------

-- Jet errors
local errs = {
    [11] = "entries must be either strings or tables.",
    [12] = "'uri' field is required for all table entries.",
    [20] = "'git' not found. Some commands may not work."
}

-- Get formatted error string from error code
local function get_err(code)
    return "Jet E" .. code .. ": " .. errs[code]
end

-- Joins two lists together
local function join_lists(a, b)
    for _, v in ipairs(b) do
        a[#a + 1] = v
    end
    return a
end

-- Returns the plugin name provided by user if available,
-- otherwise obtains name from plugin uri.
local function get_plugin_name(plugin)
    -- If its just a uri, match the tail part.
    if type(plugin) == "string" then
        local uri = plugin
        -- Check if it ends in .git, which will be ignored by the match.
        local pat = string.match(uri, "%.git$") and ".*/(.*).git$" or ".*/(.*)$"
        return string.match(uri, pat)
    else
        if plugin.name ~= nil then
            -- Return name if field is present
            return plugin.name
        else
            -- If not, recurse to obtain name from uri
            return get_plugin_name(plugin.uri)
        end
    end
end

-- Returns clone args provided by user if available,
-- otherwise returns default args.
local function get_plugin_flags(plugin)
    if type(plugin) == "string" or plugin.flags == nil then
        return { "--depth", "1" }
    else
        return plugin.flags
    end
end

-- Check if a plugin is opt or not
local function is_opt_plugin(group, plugin)
    for _, val in pairs(registry[group].opt) do
        if val == plugin then return true end
    end
    return false
end

-- Returns the installation dir for a plugin
local function get_plugin_dir(group, plugin)
    local parent = is_opt_plugin(group, plugin) and "/opt/" or "/start/"
    local name = get_plugin_name(plugin)

    return pack_dir .. "/pack/" .. group .. parent .. name
end

local function get_plugin_uri(plugin)
    if type(plugin) == "string" then
        return plugin
    else
        return plugin.uri
    end
end

-- Check if a plugin is installed
local function is_installed(group, plugin)
    local name = get_plugin_name(plugin)
    local path1 = pack_dir .. "/pack/" .. group .. "/start/" .. name
    local path2 = pack_dir .. "/pack/" .. group .. "/opt/" .. name

    -- We will consider a plugin "installed"
    -- if the .git directory is present
    local f1 = io.open(path1 .. "/.git/HEAD", "r")
    local f2 = io.open(path2 .. "/.git/HEAD", "r")

    if f1 == nil and f2 == nil then
        -- If both nil, then we assume plugin
        -- isn't installed
        return false
    else
        -- Use pcall to silence errors, since one
        -- of f1 or f2 will be nil, which would
        -- otherwise upset io.close()
        pcall(function () io.close(f1) end)
        pcall(function () io.close(f2) end)
        return true
    end
end

-------------------------------------------------------------------------------
----- JET BUFFER --------------------------------------------------------------
-------------------------------------------------------------------------------

-- Opens a custom buffer for Jet
local function open_jet_buf()
    local winnr = vim.fn.bufwinnr("Jet")

    -- Return if Jet buffer window is already open
    if winnr == vim.fn.winnr() then
        return
    elseif winnr < 0 then
        -- First, remember if the buffer already existed
        local existed = vim.fn.bufnr("Jet") > 0
        -- Get the bufnr, creating it if it didn't already exist
        local bufnr = vim.fn.bufnr("Jet", 1)

        -- Open a window and load the buffer
        vim.fn.execute("vertical topleft new | b" .. bufnr)

        -- Prepare buffer if new one was created
        if not(existed) then
            vim.cmd("setfiletype Jet")

            vim.opt_local.bufhidden = "hide"
            vim.opt_local.buftype = "nofile"
            vim.opt_local.swapfile = false
            vim.opt_local.buflisted = false

            vim.opt_local.statusline = "%= Jet %=%*"
            vim.opt_local.syntax = "markdown"

            vim.fn.setline(1, "# Jet")
            vim.fn.setline(2, "")
        end
    else
        -- If buf window was already open, switch to it
        vim.fn.execute(winnr .. "wincmd w")
    end
end

-- Logs to the custom Jet buffer
local function log(...)
    open_jet_buf()

    vim.opt_local.modifiable = true

    local args = {...}
    for _, val in ipairs(args) do
        vim.fn.append(vim.fn.line("$"), val)
    end

    vim.opt_local.modifiable = false
end

-- Remember line numbers for logs
local log_lines = {}

-- Adds a prefix in front
local function log_to(id, text)
    open_jet_buf()
    vim.opt_local.modifiable = true

    local str = "<" .. id .. "> " .. text

    local line_nr = log_lines[id]
    if line_nr == nil then
        -- Get the last line of the buffer
        line_nr = vim.fn.line("$")
        -- Store the line nr + 1, because append writes to the line below
        log_lines[id] = line_nr + 1
        vim.fn.append(line_nr, str)
    else
        vim.fn.setline(line_nr, str)
    end

    vim.opt_local.modifiable = false
end

-- Logs message with error highlighting
local function echo_err(str)
    vim.cmd("echohl Error")
    vim.cmd("echom '" .. str .. "'")
    vim.cmd("echohl None")
end

-- Clear previous contents of Jet buf and reset log_lines
local function clear_jet_buf()
    open_jet_buf()

    vim.opt_local.modifiable = true
    vim.fn.deletebufline("Jet", 2, vim.fn.line("$"))
    vim.opt_local.modifiable = false

    log_lines = {}
end

-------------------------------------------------------------------------------
----- JET GROUPS --------------------------------------------------------------
-------------------------------------------------------------------------------

local Group = {}

-- Create new Group instance, and add it to the registry.
function Group:new(name)
    -- Create group instance
    local obj = {name = name}
    self.__index = self

    -- Add group to registry
    registry[name] = {opt = {}, start = {}}

    return setmetatable(obj, self)
end

-- TODO: move plugin to correct start/opt dir after
-- checking if theyre installed, based on user's config

-- Register start plugin
function Group:start(list)
    for _, val in ipairs(list) do
        local t_val = type(val)

        if t_val ~= "string" and t_val ~= "table" then
            echo_err(get_err(11))
        elseif t_val == "table" and val.uri == nil then
            echo_err(get_err(12))
        else
            table.insert(registry[self.name].start, val)
        end
    end
end

-- Register opt plugin
function Group:opt(list)
    for _, val in ipairs(list) do
        local t_val = type(val)

        if t_val ~= "string" and t_val ~= "table" then
            echo_err(get_err(11))
        elseif t_val == "table" and val.uri == nil then
            echo_err(get_err(12))
        else
            table.insert(registry[self.name].opt, val)
        end
    end
end

-- Expose function for creating groups
local function group(name)
    return Group:new(name)
end

-------------------------------------------------------------------------------
----- JetStatus ---------------------------------------------------------------
-------------------------------------------------------------------------------

local function status()
    clear_jet_buf()
    log("", "Status", "------")

    for group, plugins in pairs(registry) do
        log("")

        for _, plugin in ipairs(plugins.opt) do
            local installed = is_installed(group, plugin)
            local id = group .. ":" .. get_plugin_name(plugin)

            if installed then
                log_to(id, "OK!")
            else
                log_to(id, "missing!")
            end
        end

        for _, plugin in ipairs(plugins.start) do
            local installed = is_installed(group, plugin)
            local id = group .. ":" .. get_plugin_name(plugin)

            if installed then
                log_to(id, "OK!")
            else
                log_to(id, "missing!")
            end
        end
    end
end

-------------------------------------------------------------------------------
----- JetInstall --------------------------------------------------------------
-------------------------------------------------------------------------------

-- Spawn git process to install a plugin
local function install(group, plugin)
    local id    = group .. ":" .. get_plugin_name(plugin)
    local flags = get_plugin_flags(plugin)
    local uri   = get_plugin_uri(plugin)
    local dir   = get_plugin_dir(group, plugin)

    -- To read command output
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local on_read = vim.schedule_wrap(function (err, data)
        if err then
            log_to(id, err)
        elseif data then
            local lines = string.gmatch(data, "[^\r\n]*")
            for line in lines do
                if string.match(line, "[^%s]") then
                    log_to(id, line)
                end
            end
        end
    end)

    -- Prepare command
    local cmd = "git"

    local opts = {
        args = join_lists({"clone", uri, dir, "--progress" }, flags),
        detached = true,
        hide = true,
        stdio = {nil, stdout, stderr}
    }

    local on_exit = function (code, signal)
        spawn_handles[uri]:close()
        spawn_handles[uri] = nil

        stdout:read_stop()
        stderr:read_stop()

        stdout:close()
        stderr:close()

        log_to(id, "Finished.")
    end

    -- Run command
    local handle, pid = vim.loop.spawn(cmd, opts, on_exit)

    -- Store handle so it can later be closed by on_exit
    spawn_handles[uri] = handle

    -- Start reading command output
    vim.loop.read_start(stdout, on_read)
    vim.loop.read_start(stderr, on_read)
end

-- Checks which ones are uninstalled and spawns install process for them.
local function install_plugins()
    clear_jet_buf()
    log("", "Install", "-------")

    local uninstalled = 0
    for group, plugins in pairs(registry) do
        for _, plugin in pairs(plugins.opt) do
            if not(is_installed(group, plugin)) then
                install(group, plugin)
                uninstalled = uninstalled + 1
            end
        end

        for _, plugin in pairs(plugins.start) do
            if not(is_installed(group, plugin)) then
                install(group, plugin)
                uninstalled = uninstalled + 1
            end
        end
    end

    if uninstalled == 0 then
        log("Nothing to install!")
    end
end

-------------------------------------------------------------------------------
----- JetUpdate ---------------------------------------------------------------
-------------------------------------------------------------------------------

local function is_update_available()
    -- Some git magic needed here lol
    return false
end

local function update()
    -- Spawn git pull process
end

local function update_plugins()
    -- loop over each registry entry
        -- if is_update_available() then
            -- update()
        -- end
    -- end
end

-------------------------------------------------------------------------------
----- Jet.pack ----------------------------------------------------------------
-------------------------------------------------------------------------------

local function pack(tbl)
    if vim.fn.executable("git") ~= 1 then
        echo_err(get_err(20))
    end

    pack_dir = tbl.path
    vim.cmd("set packpath+=" .. pack_dir)

    vim.cmd([[
    command -nargs=0 JetInstall lua Jet.install()
    command -nargs=0 JetUpdate lua Jet.update()
    command -nargs=0 JetStatus lua Jet.status()
    command -nargs=0 JetClean lua Jet.clean()
    command -nargs=1 JetLoad packadd <args>
    ]])

    local handle = io.popen([[eval "$(ssh-agent -s)" && ssh-add ]] .. tbl.ssh)
    handle:close()
end

Jet = {
    pack = pack,
    group = group,
    install = install_plugins,
    update = update_plugins,
    clean = clean_plugins,
    status = status,
}

