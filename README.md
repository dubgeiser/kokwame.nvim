# Kokwame

Code Quality Metrics
KOde KWality MEtrics, gettit (I'll get me coat).

Kokwame is a Neovim plugin in Lua that calculates code quality metrics per
code unit.  A code unit is typically a method or a function.
Per code unit following metrics are calculated:

  - Cyclomatic Complexity
  - ... that is all for now :-)

## Requirements
Kokwame uses [treesitter] and Nvim's built in LSP support to do its work.

## Install and setup
Kokwame can be installed via the default way of your favorite package manager.

```lua
-- The options table is an optional argument,
-- it is shown here with the default value for produce_diagnostics
require('kokwame').setup({ produce_diagnostics = false })
```

## Usage
There are 2 ways you can put Kokwame to work:

### `:KokwameInfo`
This is more of a on-the-fly mode of Kokwame; you issue the command
`:KokwameInfo` and all the metrics of the code unit that the cursor is in will
be shown in a popup window.

### LSP Diagnostics integration (EXPERIMENTAL!)
When the option `produce_diagnostics` is set to `true` in the options that you
pass to the `setup()` function, Kokwame will integrate with Neovim's LSP
support and render the metrics inline as LSP diagnostics.
Depending on how each metric is configured, these metric will show up as
error, hint, warning, etc... or not at all (Cyclomatic complexity of 2 doesn't
seem like a good warning or error to show, for instance ;-) )

## Help
See `:help kokwame` in Neovim for the help, or see the `kokwame.txt` file in
the `doc/` directory for more info.

## Reference
These two links helped me out a lot to get something working with the
nvim-treesitter plugin.  

  - [contextprint](https://github.com/polarmutex/contextprint.nvim/blob/main/lua/contextprint/nodes.lua)
  - [nvim-treesiter/ts_utils.lua](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/lua/nvim-treesitter/ts_utils.lua)
  - Various help pages in Neovim re. LSP, diagnostics, etc...

Thanks to/for [treesitter-playground](https://github.com/nvim-treesitter/playground) which helped me out a lot.

[treesitter]: https://github.com/nvim-treesitter/nvim-treesitter

<!--:vim:tw=78:wrapmargin=78:spell::-->
