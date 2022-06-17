# Jet

Jet is a plugin/package manager for neovim. The aim is to find a middleground
between the lightweight [paq-nvim](https://github.com/savq/paq-nvim)
and the heavyweight [packer.nvim](https://github.com/wbthomason/packer.nvim).

> ⚠ Jet is still in development stages - most features mostly work, but there
> is still testing and bug-hunting to be done. Please feel free to open an
> issue if you encounter bugs or any strange behaviour.

## Features
- Written and configured in lua
- Lazy-loading capabilities
- Async installation
- Install/update hooks
- Group plugins into "packs", making large configurations more manageable

## Installation

> NOTE: The plugin has not been tested for versions older than v0.7.0, but
> should still work more or less for previous versions, at least up to v0.5.0.
> If you find any bugs with older versions feel free to open an issue.

#### UNIX / Linux
```
git clone --filter=blob:none https://github.com/quintik/jet-nvim ~/.local/share/nvim/site/pack/jet/start/jet-nvim
```

#### Windows
```
git clone --filter=blob:none https://github.com/quintik/jet-nvim "$env:LOCALAPPDATA\nvim-data\site\pack\jet\start\jet-nvim"
```

## Usage

Once installed you can write your Jet configuration in your `init.lua` (or any
runtime/sourced lua file).

```lua
local Jet = require "jet"

-- Let Jet manage itself.
Jet.pack "jet" { "https://github.com/quintik/jet-nvim" }

-- Your plugin configuration, grouped under "myplugins".
Jet.pack "myplugins" {
    -- You can supply just the uri:
    "https://github.com/author/plugin"

    -- Or a table:
    { uri  = "https://github.com/quintik/jet-nvim",
      name = "jet" },

    -- Example with all options (read below for more details):
    { uri   = "https://github.com/author/plugin",
      name  = "myplugin",
      opt   = true,
      args  = { "--branch", "dev" },
      on    = { "CmdUndefined MyCommand" },
      pat   = { ".ft" },
      cfg   = function() require "cfg" end,
      run   = function(e) if e === "install" then doSmth() else doSmthElse() end end }
}
```

## LICENSE

[MIT](https://github.com/quintik/jet-nvim/blob/master/LICENSE).
