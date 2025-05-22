# gopls.nvim

gopls utilities for Neovim. Implements some gopls lsp commands that are not seen in other plugins

## Install 

```lua
  {
    "jackielii/gopls.nvim",
    keys = {
      {
        "<leader>kgl",
        function()
          require("gopls").list_known_packages({with_parent = true, loclist = true})
        end,
        desc = "List known packages",
      },
      {
        "<leader>kgp",
        function()
          require('gopls.snacks_picker').list_package_symbols({with_parent = true})
        end,
        desc = "List package symbols",
      },
    }
  }
```

## Features

- [x] gopls.list_known_packages

  ![list-known-packages](assets/list-known-packages.png)

  Upon selecting an item, a new import statement will be inserted

- [x] gopls.package_symbols

  Use `require('gopls.snacks_picker').list_package_symbols()` to put the package symbols to location list, similar to `:h vim.lsp.buf.document_symbol()`

  Or with [snacks picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) as shown in lazy keys:
  ![snacks-picker-package-symbols](assets/snacks-picker-package-symbols.png)

  You're welcome to add support for another picker by sending a PR
