local fn = vim.fn

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

-- Get formatted error string from error code.
local function get_err_str(code)
    return "Jet E" .. code .. ": " .. errs[code]
end

-- Write `msg` to log file along with timestamp.
local function write(msg)
    -- Make sure log_handle is available.
    if log_handle ~= nil then
        local str = os.date("[%Y-%b-%d | %H:%M] ") .. msg .. "\n"
        log_handle:write(str)
    end
end

-- Executes pending writes to a file.
local function flush()
    if log_handle ~= nil then
        log_handle:flush()
    end
end


-- Echoes error message (from the given `code`).
-- Flush logs here since err may be executed outside
-- of functions ran by editor commands.
local function err(code)
    write(get_err_str(code))

    vim.cmd("echohl Error")
    vim.cmd("echom '" .. get_err_str(code) .. "'")
    vim.cmd("echohl None")

    flush()
end

-- Clear log file if larger than 500KB
if fn.getfsize(LOG_FILE) >= 500000 then fn.writefile({}, LOG_FILE) end
-- Notify user if unable to open log file, otherwise
-- register autocmd for closing file on exit.
if log_handle == nil then
    err(30)
else
    vim.cmd "autocmd VimLeavePre * lua require'jet'.log_handle:close()"
end

return {
    LOG_FILE = LOG_FILE,
    write = write,
    flush = flush,
    err   = err
}
