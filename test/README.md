## Run tests

I'm not really sure how else to test this plugin, this is
the best I could come up with.

- `cd` into jet's root directory (wherever you cloned it.)
- In that directory, open vim with the basic config included in test/ by running `nvim -u test/basic-cfg.vim`
- Run `:lua require "lua/jet"` to load jet first.
- Run `:lua require"test/testx".prep()` to prep the test, where `x` is the test number.
- Run `:lua require"test/testx".run()` to actually run the test.

Here's what each file tests:

| Test # | Description       |
|--------|-------------------|
| test1  | JetInstall [pack] |
| test2  | JetUpdate [pack]  |
| test3  | JetClean          |
| test4  | JetList           |
| test5  | JetAdd <pack>     |

