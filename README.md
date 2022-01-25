# Jet

Jet is a simple, single-file plugin manager for neovim. The aim is to
find a middleground between the lightweight [paq-nvim](https://github.com/savq/paq-nvim)
and the heavyweight [packer.nvim](https://github.com/wbthomason/packer.nvim).

> ⚠ Jet is not yet at a 'stable' stage - most features mostly work, but
> there is still testing and bug-hunting to be done. Please feel free to
> open an issue if you encounter bugs or strange behaviour.

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

## Commands

- `JetInstall [pack]`: Installs missing plugins. If `pack` is given, install
  missing plugins from that pack.
- `JetUpdate [pack]`: Updates all plugins. If `pack` is given, updates plugins
  from that pack.
- `JetClean`: Cleans all unused plugins.
- `JetList`: Shows list of installed and missing plugins.
- `JetAdd <plugin>`: Immediately loads the specified plugin.
- `JetLog`: Opens log file.

## Options

The following options are available for table entries in your Jet
configuration:

#### `uri`
Type: `string`

This option is always required for table entries. This is the uri for the
plugin. Note that unlike other plugin managers, the uri must be in full, that
is it cannot be in the shortened form "author/plugin".

#### `name`
Type: `string`

An alternative name for the plugin, to be used locally. By default, the name is
taken from the repository uri.

#### `opt`
Type: `boolean`

If true, the plugin will not be loaded on startup. To load it, you can use
`JetAdd <plugin>` at any time, or configure it to lazy load when specific
events are triggered. See below for more details. By default, all plugins
are loaded on startup, that is, `opt = false`.

#### `flags`
Type: `table`

This is a list of extra flags and arguments to supply to the git command when
cloning or pulling from the remote repository. The default is value is
`{ "--depth", 1 }`, which makes installing faster since it does not clone the
entire history of the repository. If you don't want this, you can supply a
list without these options. This option can also be used for cloning specific
branches or tags. Note that these flags are used both when installing and
updating plugins.

#### `on`
Type: `table`

This is a list of event names which, when triggered, will load the plugin. See
`:h events` for a list of possible events. Under the hood, Jet simply registers
an autocmd (see `:h autocmd`) for these events, and a function that will load
the plugin when the event is fired. This, of course, only affects `opt` plugins
(that is, plugins for which `opt = true`). `start` plugins (plugins for which
`opt = false`), are always loaded on startup and so this has no effect on them.

#### `pat`
Type: `table`

This is a list of patterns for the autocmd registered for `opt` plugins. See
`:h autocmd` for more details.

#### `cfg`
Type: `function`

This function is executed whenever a plugin (`opt` or `start`) is loaded. It
can be used for plugin-specific configuration. Note that this function is
called *after* the plugin is loaded.

## More Examples

TODO. For now, you can take a look [here](https://github.com/quintik/turbo-octo/blob/master/lua/jet-config.lua).

## LICENSE

[MIT](https://github.com/quintik/jet-nvim/blob/master/LICENSE).

