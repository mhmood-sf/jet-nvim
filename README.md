# Jet

Jet is a simple, single-file (~500LOC) plugin manager for neovim. The aim is to
find a middleground between the lightweight [paq-nvim](https://github.com/savq/paq-nvim)
and the heavyweight [packer.nvim](https://github.com/wbthomason/packer.nvim).

> ⚠ Jet is not yet at a 'stable' stage - most features mostly work, but
> there is still testing and bug-hunting to be done. Please feel free to
> open an issue if you encounter bugs or strange behaviour.

## Features
- Written and configured in lua
- Lazy-loading capabilities
- Async installation
- Group plugins into "packs"

## Installation

You can either clone this repository into your `lua/` directory:
```
git clone https://github.com/quintik/jet-nvim ~/.config/nvim/lua/
```
...or you can simply install the `jet.lua` file into your `lua/` directory:
```
curl -o ~/.config/nvim/lua/jet.lua https://raw.githubusercontent.com/quintik/jet/master/jet.lua
```

## Usage

```lua
require "jet"

-- All plugins are grouped under "packs", and each pack
-- is stored in `pack_path/<pack>/` (see :h packpath).
Jet.pack "myplugins" {
    -- You can supply just the uri:
    "https://github.com/quintik/qline"

    -- Or a table:
    { uri  = "https://github.com/quintik/Snip",
      name = "nvim_snip",
      opt  = true },

    -- Example with all options (see Options for more details):
    { uri   = "https://github.com/author/plugin",
      name  = "plugin",
      opt   = true,
      flags = { "--branch", "dev" },
      on    = "Event",
      pat   = "*",
      cfg   = function() require "cfg" end }
}
```

## Commands

- `JetInstall [pack]`: Installs missing plugins. If `pack` is given, install missing plugins from that pack.
- `JetUpdate [pack]`: Updates all plugins. If `pack` is given, install missing plugins from that pack.
- `JetClean`: Cleans unused packs and plugins.
- `JetList`: Shows list of installed and missing plugins.
- `JetAdd <pack>`: Immediately loads all plugins for the given pack.

## Options

Jet supports the following options:
| Option | Type     | Description                                             |
|--------|----------|---------------------------------------------------------|
| uri    | string   | Required. The uri for the plugin.                       |
| name   | string   | Alternative name for the plugin to use locally.         |
| opt    | boolean  | If true, the plugin will not be loaded on startup.      |
| flags  | table    | Extra flags/args to supply to git commands.             |
| on     | string   | Event name for lazy loading plugins. See `:h autocmd`   |
| pat    | string   | Pattern for lazy loading plugins. See `:h autocmd`      |
| cfg    | function | Executed after a plugin is lazy loaded.                 |
