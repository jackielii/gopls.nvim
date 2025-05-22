# gopls.nvim
gopls utilities for Neovim

```lua
  {
    "jackielii/gopls.nvim",
    config = true,
    keys = {
      {
        "<leader>kgl",
        function()
          require("gopls").list_known_packages()
        end,
      }
    }
  }
```


## Features
- [x] gopls.list_known_packages
  ![list-known-packages](assets/list-known-packages.png)
  Upon selecting an item, a new import statement will be inserted
- [x] gopls.package_symbols


