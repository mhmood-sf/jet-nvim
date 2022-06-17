local fn = vim.fn

-- Path to pack dir.
local PACK_DIR = vim.g.jet_pack_dir or (fn.stdpath("data") .. "/site/pack/")

-- Concatenates args after PACK_DIR to construct the
-- path to a pack's opt/start dir or a plugin dir.
-- Basically returns "<PACK_DIR>/<pack>/<opt>/<plugin?>".
-- The `plugin` arg is optional.
local function mk_path(pack, opt, plugin)
    return PACK_DIR .. pack .. "/" .. opt .. "/" .. (plugin or "")
end

-- Returns plugin with the specified `name`.
-- This is also why we can't allow plugins with the same name :/
local function find_plugin(name, registry)
    for _, plugin in ipairs(registry) do
        if plugin.name == name then
            return plugin
        end
    end
end

-- Returns git process args if provided by user,
-- otherwise the defaults.
local function get_plugin_args(plugin)
    if type(plugin) == "string" or plugin.args == nil then
        -- See: https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/
        -- Shallow clones will still download the entire history
        -- when updating, so we use partial clones to avoid that.
        return { "--filter=blob:none" }
    end
    return plugin.args
end

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

return {
    mk_path = mk_path,
    find_plugin = find_plugin,
    get_plugin_args = get_plugin_args,
    get_plugin_name = get_plugin_name
}
