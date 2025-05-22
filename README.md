# gopls.nvim

`gopls` exposes many commands via `workspace/executeCommand` which is not readily available through lsp clients. This repo implements a few of them to make your life easier.

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
        desc = "Gopls list known packages",
      },
      {
        "<leader>kgp",
        function()
          require('gopls.snacks_picker').list_package_symbols({with_parent = true})
        end,
        desc = "Gopls list package symbols",
      },
      {
        "<leader>kgd",
        function()
          require('gopls.snacks_picker').doc({show_document = true})
        end,
        desc = "Gopls show documentation",
      },
    }
  }
```

## Features

- [x] gopls.list_known_packages

  ![list-known-packages](assets/list-known-packages.png)

  Upon selecting an item, a new import statement will be inserted

- [x] gopls.package_symbols

  Use `require('gopls').list_package_symbols()` to put the package symbols to location list or quickfix, similar to `:h vim.lsp.buf.document_symbol()`

  Or with [snacks picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) as shown above in the install section:
  ![snacks-picker-package-symbols](assets/snacks-picker-package-symbols.png)

  You're welcome to add support for another picker by sending a PR

- [x] gopls.doc

  Show documentation for the symbol under cursor. If `opts.show_document=true`, it will open a browser window,
  otherwise it will copy the url to clipboard

- [x] gopls.tidy

  Run `go mod tidy`.

- [x] gopls.vendor

  Run `go mod vendor`.

- [x] gopls.add_test

  Add a test function for the function under cursor.

- [ ] gopls.add_dependency
- [ ] gopls.add_import
- [ ] gopls.add_telemetry_counters
- [ ] gopls.apply_fix
- [ ] gopls.assembly
- [ ] gopls.change_signature
- [ ] gopls.check_upgrades
- [ ] gopls.client_open_url
- [ ] gopls.diagnose_files
- [ ] gopls.edit_go_directive
- [ ] gopls.extract_to_new_file
- [ ] gopls.fetch_vulncheck_result
- [ ] gopls.free_symbols
- [ ] gopls.gc_details
- [ ] gopls.generate
- [ ] gopls.go_get_package
- [ ] gopls.list_imports
- [ ] gopls.maybe_prompt_for_telemetry
- [ ] gopls.mem_stats
- [ ] gopls.modify_tags
- [ ] gopls.modules
- [ ] gopls.packages
- [ ] gopls.regenerate_cgo
- [ ] gopls.remove_dependency
- [ ] gopls.reset_go_mod_diagnostics
- [ ] gopls.run_go_work_command
- [ ] gopls.run_govulncheck
- [ ] gopls.run_tests
- [ ] gopls.scan_imports
- [ ] gopls.start_debugging
- [ ] gopls.start_profile
- [ ] gopls.stop_profile
- [ ] gopls.update_go_sum
- [ ] gopls.upgrade_dependency
- [ ] gopls.views
- [ ] gopls.vulncheck
- [ ] gopls.workspace_stats

