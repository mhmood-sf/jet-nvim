# Jet

Jet is a simple, single-file plugin manager for neovim. The aim is to
find a middleground between the lightweight [paq-nvim](https://github.com/savq/paq-nvim)
and the heavyweight [packer.nvim](https://github.com/wbthomason/packer.nvim).

> ⚠ Jet is still in development stages - many features mostly work, but
> there is still testing and bug-hunting to be done, and breaking changes
> may be made at any time. Information in the README may also be outdated.
> Please feel free to open an issue if you encounter bugs or strange behaviour,
> or need help with this plugin.

## Features
- Written and configured in lua
- Lazy-loading capabilities
- Async installation
- Group plugins into "packs", making large configurations more manageable

## Installation

> NOTE: The plugin has not been tested for versions older than 0.5.0, but
> should still work more or less. If you find any bugs feel free to open an
> issue.

#### UNIX / Linux
```
git clone --depth 1 https://github.com/quintik/jet-nvim ~/.local/share/nvim/site/pack/jet/start/jet-nvim
```

#### Windows
```
git clone --depth 1 https://github.com/quintik/jet-nvim "$env:LOCALAPPDATA\nvim-data\site\pack\jet\start\jet-nvim"
```

## Usage

Once installed you can write your Jet configuration in your `init.lua` (or any
runtime/sourced lua file).

```lua
local Jet = require "jet"

-- Let Jet manage itself.
Jet.pack "jet" { "https://github.com/quintik/jet-nvim" }

-- Your plugin specification, grouped under "myplugins".
Jet.pack "myplugins" {
    -- You can supply just the uri:
    "https://github.com/author/plugin"

    -- Or a table:
    { uri  = "https://github.com/quintik/jet-nvim",
      name = "jet" },

    -- Example with all options (read below for more details):
    { uri   = "https://github.com/author/plugin",
      name  = "plugin",
      opt   = true,
      flags = { "--branch", "dev" },
      on    = { "Event" },
      pat   = { ".ft" },
      cfg   = function() require "cfg" end }
}
```

## More Examples

TODO. For now, you can take a look [here](https://github.com/quintik/turbo-octo/blob/master/lua/jet-config.lua).

## LICENSE

[MIT](https://github.com/quintik/jet-nvim/blob/master/LICENSE).

