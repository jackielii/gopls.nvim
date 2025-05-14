# gopls.nvim
gopls utilities for Neovim

## gopls.list_known_packages

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
