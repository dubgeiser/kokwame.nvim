# Kokwame

Code Quality Metrics
KOde KWality MEtrics, gettit (I'll get me coat).

Kokwame is a Neovim plugin in Lua that calculates code quality metrics per
code unit.  A code unit is typically a method or a function.
Per code unit following metrics are calculated:

  - Cyclomatic Complexity
  - ... that is all for now :-)


## Requirements
Kokwame uses internally both [lspconfig] and [treesitter] .  See their
instructions to install.

## Usage
### `KokwameToggle`
Require the kokwame lib:
```lua
require('kokwame')
```
Use the command `:KokwameToggle` to display the metrics.

### LSP Diagnostics integration (EXPERIMENTAL!)
Kokwame will integrate with the LSP client via [lspconfig](https://github.com/neovim/nvim-lspconfig)
Note that this is still _*very much experimental*_ and you have to configure this
manually:
```Lua
local kokwame = require('kokwame')
local lspconf = require('lspconfig')
local lspservers = { 'pyright', 'phpactor' }
local on_attach = function(client, bufnr)
  -- other lspconfig setups here...
  kokwame.diagnostics(client, bufnr)
end
for _, lspserver in ipairs(lspservers) do
  lspconf[lspserver].setup({
    capabilities = capabilities,
    on_attach = on_attach,
  })
end
```
The metrics will be shown inline, like any other LSP diagnostics.

### Help
Not yet implemented, but when it is, type `:help kokwame`

## Reference
These two links helped me out a lot to get something working with the
nvim-treesitter plugin.  

  - [contextprint](https://github.com/polarmutex/contextprint.nvim/blob/main/lua/contextprint/nodes.lua)
  - [nvim-treesiter/ts_utils.lua](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/lua/nvim-treesitter/ts_utils.lua)

Thanks to/for [treesitter-playground](https://github.com/nvim-treesitter/playground) which helped me out a lot.

[treesitter]: https://github.com/nvim-treesitter/nvim-treesitter
[lspconfig]: https://github.com/neovim/nvim-lspconfig

<!-- vim: set tw=78 wrapmargin=78 spell: -->
