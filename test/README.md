## Running tests

I'm not really sure how else to test this plugin, this is
the best I could come up with.

- `cd` into jet's root directory (wherever you cloned it.)
- In that directory, open vim with the basic config included in test/ by running `nvim -u test/basic-cfg.vim`
- Run `:Test {x}` where `{x}` is the test number to run (see below).

Here's what each file tests:

| Test # | Description             |
|--------|-------------------------|
| test1  | Tests JetInstall [pack] |
| test2  | Tests JetUpdate [pack]  |
| test3  | Tests JetClean          |
| test4  | Tests JetList           |
| test5  | Tests JetAdd <pack>     |

## To-Do

- [ ] Also write tests for local functions in jet.
- [ ] Need more failing test cases.
- [ ] ?
