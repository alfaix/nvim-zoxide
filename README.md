# nvim-zoxide

A neovim plugin that provides helpful wrappers around [zoxide].

## Features

* Out-of-the-box commands (`:Z[!]`, `:Zt[!]`, `:Zw[!]`)
* Lua interface
* Telescope integration

## Installation

This plugin depends on [plenary.nvim] and, optionally, on [telescope.nvim].
Best to install with [lazy.nvim]:

```lua
{
    "alfaix/nvim-zoxide",
    dependencies = {"nvim-lua/plenary.nvim"}
    opts = {
        -- will define Z[!], Zt[!], Zw[!] for :cd, :tcd, :lcd respectively 
        -- set to false if you want to define different ones
        define_commands = true,
        -- path to zoxide executable; by default must be in $PATH
        path = "zoxide",
},
-- optional for telescope integration
{
    "nvim-telescope/telescope.nvim",
    opts = {
        -- your other telescope configuration is here
        extensions = {
            -- you can put theme options here, e.g.
            -- ["zoxide"] = require"telescope.themes".get_dropdown({})
            -- not that require"telescope.themes" will likely need moving 
            -- this to config() instead of opts depending on your lazy setup
            ["zoxide"] = {}
        }
    },
    config = function(_, opts)
        -- other stuff, such as require"telescope".setup(opts)
        -- you can skip this but tab completion for it won't be available 
        -- until it's lazy-loaded
        -- https://github.com/nvim-telescope/telescope.nvim?tab=readme-ov-file#extensions
        require"telescope".load_extension("zoxide")
    end
}
```

## Usage

If `define_commands` is set, you can `:Z[t|w][!]` to a zoxide pattern, e.g.:

* `:Z somedir` to match "somedir", open a `vim.ui.select` if there are multiple
  matches, then `:cd` to the selected (or only) match.
* `:Zt! somedir` to match "somedir" and immediately `:tcd` to the best match.

For telescope integration, run `:Telescope zoxide`, `:Telescope zoxide tab`,
`:Telescope zoxide window`, or use the corresponding [extensions api][telescope-extensions].

There's also lua interface available (`zoxide.zoxide`, `zoxide.increment`,
`zoxide.cd`) if you want to implement your own functions, see init.lua for
docstrings. It is callback-based but you can convert it to coroutines via
`plenary.async.wrap` or `nio`. For your own commands, just calling `zoxide.zoxide`
with appropriate context should
be sufficient.

[zoxide]: https://github.com/ajeetdsouza/zoxide
[lazy.nvim]: https://github.com/folke/lazy.nvim/
[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[telescope-extensions]: https://github.com/nvim-telescope/telescope.nvim#extensions
[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
