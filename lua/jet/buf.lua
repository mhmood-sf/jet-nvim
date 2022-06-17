local fn = vim.fn

local log = require "jet.log"

-- Sets window/buffer options and header.
local function prep_buffer()
    log.write("Preparing Jet Buffer.")
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
local function open_window()
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
            prep_buffer()
        end
    else
        -- If buf window was already open, switch to it.
        fn.execute(winnr .. "wincmd w")
    end
end

-- Writes each arg as a line to the custom buffer.
local function write(...)
    open_window()
    vim.opt_local.modifiable = true
    for _, val in ipairs({ ... }) do
        fn.append(fn.line("$"), val)
    end
    vim.opt_local.modifiable = false
end

-- Remember line numbers for logs.
local line_ids = {}

-- Logs to a fixed line, based on it's id.
local function write_to(id, text)
    open_window()
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
local function clear()
    open_window()
    vim.opt_local.modifiable = true
    fn.deletebufline("Jet", 2, fn.line("$"))
    vim.opt_local.modifiable = false
    line_ids = {}
end

return {
    clear = clear,
    write = write,
    write_to = write_to
}
