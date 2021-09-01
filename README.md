# Jet

Jet is a simple, single-file plugin manager for neovim.

### Installation

Install `jet.lua` into the `lua/` directory:
```
curl -o ~/.config/nvim/lua/jet/jet.lua https://raw.githubusercontent.com/quintik/jet/master/jet.lua
```

### Usage

Add a lua block for your Jet config inside your init.vim:
```lua
lua << EOF
require "jet/jet"

-- Initialize Jet with a table containing two fields:
-- path: path to your `pack` directory, usually
--       just `~/.config/nvim`, but can be different
--       if you want to install your plugins elsewhere.
-- ssh:  path to ssh key if you want Jet to
--       automatically start the ssh agent if you use
--       that for git.
Jet.pack { path = "~/.config/nvim", ssh = "~/.ssh/id_rsa" }

-- Create a new group for plugins. These plugins will
-- be stored under `pack/<group>/`.
local quintik = Jet.group "quintik"

-- Plugins registered with `<group>:start` are always
-- loaded on startup. These are placed under
-- `pack/<group>/start/`.
quintik:start {
    "git@github.com:quintik/qline",
    "git@github.com:quintik/snap"
}

-- Other plugins
local jet = Jet.group "jet"

jet:start {
    "git@github.com:ervandew/supertab",
    "git@github.com:jiangmiao/auto-pairs",
    "git@github.com:vimwiki/vimwiki"
}


--[[
local test = Jet.group "test"

test:start {
    "uri",

    {
        uri = "uri",
        name = "gloop",
        flags = { "--depth", "1", "--branch", "feature/xclip" }
    }
}

test:opt {
    "uri",

    {
        uri = "uri",
        name = "glopt",
        args = { "--depth", "1", "--branch", "feature/xclip" },
        load_evt = "CmdUndefined",
        load_fn = function(match, _buf, _file) return match == "Telescope" end,
        post_load = function() print("Telescope loaded.") end,
        post_install = function() print("Telescope installed.") end
    }
}
--]]

EOF
```

