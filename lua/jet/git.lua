--- This module handles spawning git processes.
-- @module git

local fn = vim.fn
local uv = vim.loop

local log = require "jet.log"
local buf = require "jet.buf"

local load_plugin = require("jet.plugin").load
local mk_path = require("jet.helpers").mk_path


-- Path to pack dir.
local PACK_DIR = vim.g.jet_pack_dir or (fn.stdpath("data") .. "/site/pack/")

--- Spawn a git process.
-- Spawn a git process with the given `opts` (this is the options object
-- passed on to vim.loop.spawn). The `on_read` and `on_exit` callbacks
-- callbacks are used for stdout/stderr, which are created and handled
-- by the function (that is, custom stdout/stderr pipes are not
-- supported. They are ignored even if attached to the opts object).
-- Note that the `on_read` callback is ONLY used for stderr, since git
-- output is sent to stderr instead of stdout (which is only used for
-- important inter-process messages). Output to stdout is written to
-- the log file.
-- @tparam table opts: See https://github.com/luvit/luv/blob/master/docs.md#uvspawnpath-options-on_exit
-- @tparam function on_read: Callback passed to `stderr:read_start(...)`.
-- @tparam function on_exit: Callback ran when the process exits.
local function spawn_git(opts, on_read, on_exit)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    opts.stdio = { nil, stdout, stderr }

    -- Declare vars so we can close them in the exit callback.
    local handle, pid

    -- Spawn process with opts and exit callback.
    -- Also schedule_wrap callback in case on_exit invokes the Nvim
    -- API (otherwise, API functions are not allowed in event loop).
    handle, pid = uv.spawn("git", opts, vim.schedule_wrap(function(code)
        -- Close handles and pipes.
        if not handle:is_closing() then handle:close() end
        stdout:close(); stderr:close();
        -- Log end of process.
        log.write("PID " .. pid .. ": closing process, code: " .. code)
        -- Run on_exit callback.
        on_exit(code)
    end))

    -- Start reading stdout. Most of git's output is through stderr,
    -- so for stdout we just log whatever we get.
    stdout:read_start(function(error, data)
        if error then log.write("PID " .. pid .. ": " .. error) end
        if data then log.write("PID " .. pid .. ": " .. data) end
    end)

    -- Start reading stderr. Here we call the on_read arg to handle
    -- the data, and also wrap it in case it calls the Nvim API
    stderr:read_start(vim.schedule_wrap(on_read))

    log.write("Spawned new git process with PID: " .. pid)
end

-- Returns the `on_read` callback for stdout pipe.
local function get_on_read_callback(logid)
    return function(error, data)
        if error then log.write(logid .. " error: " .. error) end
        if data then
            -- Ignore whitespace/newlines.
            local lines = string.gmatch(data, "%s*([^\r\n]*)%s*")
            for line in lines do
                -- Only write non-empty lines.
                if string.match(line, "[^%s]") ~= nil then
                    -- Only log progress from 0-9% and 100%,
                    -- and ignore the unecessary lines between.
                    if string.match(line, "[^%d]%d%d%%") == nil then
                        log.write("<" .. logid .. "> " .. line)
                    end
                    -- But for the jet buffer, we log the full
                    -- progress because it looks cool.
                    buf.write_to(logid, line)
                end
            end
        end
    end
end

-- Returns the `on_exit` callback for process handle.
-- Writes success/fail msg to jet_buf with given logid,
-- and calls hook when command finishes successfully.
local function get_on_exit_callback(logid, hook)
    return function(code)
        -- Call hook if finished successfully.
        if code == 0 then
            buf.write_to(logid, "Finished.")
            hook()
        else
            buf.write_to(logid, "Failed. Check `:JetLog` for more info.")
        end
    end
end

--- Install given plugin by running git clone.
-- Clones the remote git repository for the given plugin object
-- into its plugin directory. Note that initially, we install
-- every plugin into the optpath. The hook function we pass then
-- `:packadd`s the plugin after installation, IF the plugin is a
-- start plugin. Opts plugins are kept in the opt directory. This
-- makes it convenient since start plugins are autmatically loaded
-- when installed. The next time that nvim runs, Jet will optsync
-- them so that everything is consistent eventually.
-- @tparam table plugin: The plugin to install.
local function git_clone(plugin)
    local logid = plugin.pack .. ":" .. plugin.name
    log.write("Running git clone for: <" .. logid .. ">")

    -- Include plugin args and use optpath for installing.
    local args = { "clone", "--progress" }
    local optpath = mk_path(plugin.pack, "opt", plugin.name)
    vim.list_extend(args, plugin.args)
    vim.list_extend(args, { plugin.uri, optpath })

    -- Opts table.
    local opts = {
        args = args,
        cwd  = PACK_DIR,
    }

    -- Define hook.
    local hook = function()
        -- Call install hook. Note this is called after
        -- installation but BEFORE the plugin is loaded.
        if plugin.run then plugin.run("install") end
        -- If it's a start plugin we load it immediately.
        if not plugin.opt then load_plugin(plugin) end
    end

    -- Get callbacks and start git process.
    local on_read = get_on_read_callback(logid)
    local on_exit = get_on_exit_callback(logid, hook)
    spawn_git(opts, on_read, on_exit)
end

--- Update the given plugin with git pull.
-- Update a plugin using git pull. It is assumed there is already an
-- upstream branch, so that `git pull` is enough to update the
-- plugin.
-- @tparam table plugin: The plugin to update.
local function git_pull(plugin)
    local logid = plugin.pack .. ":" .. plugin.name
    log.write("Running git pull for: <" .. logid .. ">")

    -- Note that we only call `git pull`, so we assume
    -- there is an upstream branch already.
    local opts = {
        args = { "pull", "--progress" },
        cwd  = plugin.dir
    }

    -- Hook function just calls the update hook if there is one.
    local hook = function() if plugin.run then plugin.run("update") end end

    -- Get callbacks and start git process.
    local on_read = get_on_read_callback(logid)
    local on_exit = get_on_exit_callback(logid, hook)
    spawn_git(opts, on_read, on_exit)
end

return {
    pull = git_pull,
    clone = git_clone
}
