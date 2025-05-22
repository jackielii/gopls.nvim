local M = {}

function M.setup(opts) end

local function get_gopls_client(bufnr)
  local clients = vim.lsp.get_clients({ name = "gopls", bufnr = bufnr })
  if #clients > 0 then
    return clients[1]
  end

  vim.notify("gopls LSP client not found", vim.log.levels.ERROR)
  return nil
end

M.list_known_packages = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  local command = {
    command = "gopls.list_known_packages",
    arguments = {
      { uri = vim.uri_from_bufnr(bufnr) },
    },
  }

  gopls:exec_cmd(command, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.list_known_packages: " .. err.message, vim.log.levels.ERROR)
      return
    end

    if not result or vim.tbl_isempty(result.Packages) then
      vim.notify("No known packages returned by gopls.", vim.log.levels.WARN)
      return
    end
    local packages = result.Packages

    vim.ui.select(packages, {
      prompt = "Select a known package:",
      -- format_item = function(item)
      -- 	return item.name
      -- end,
    }, function(selected)
      if not selected then
        return
      end

      local params = {
        command = "gopls.add_import",
        arguments = {
          { uri = vim.uri_from_bufnr(bufnr), ImportPath = selected },
        },
      }
      gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
        if err then
          vim.notify("Error adding import: " .. err.message, vim.log.levels.ERROR)
          return
        end

        if result and result.success then
          vim.notify("Import added successfully.", vim.log.levels.INFO)
        else
          vim.notify("Failed to add import.", vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

--- @class gopls.list_package_symbols.Config : vim.lsp.ListOpts
--- @field with_parent boolean? : Include parent name in the symbol name

--- Lists Go package symbols in the current buffer in the |location-list|.
--- @param opts? gopls.list_package_symbols.Config
M.list_package_symbols = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { loclist = true })

  local bufnr = vim.api.nvim_get_current_buf() or 0
  local params = {
    command = "gopls.package_symbols",
    arguments = {
      { uri = vim.uri_from_bufnr(bufnr) },
    },
  }

  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result, ctx, config)
    if err then
      vim.notify("Error running gopls.package_symbols: " .. err.message, vim.log.levels.ERROR)
      return
    end
    -- P(result.PackageName, result.Files, result.Symbols)

    local symbols = require("gopls.package_symbols").package_symbols_result_to_symbols(result, opts.with_parent)
    local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
    local items = vim.lsp.util.symbols_to_items(symbols, ctx.bufnr, client.offset_encoding)
    local list = {
      title = "Package Symbols",
      items = items,
      context = ctx,
    }
    if opts.on_list then
      assert(vim.is_callable(opts.on_list), "on_list is not a function")
      opts.on_list(list)
    elseif opts.loclist then
      vim.fn.setloclist(0, {}, " ", list)
      vim.cmd.lopen()
    else
      vim.fn.setqflist({}, " ", list)
      vim.cmd("botright copen")
    end
  end)
end

--- @class gopls.doc.Config
--- @field show_document boolean? : Show the document in a browser window or copy to clipboard

--- @param opts? gopls.doc.Config
M.doc = function(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local range = vim.lsp.util.make_range_params()
  local params = {
    command = "gopls.doc",
    arguments = {
      {
        Location = {
          uri = range.textDocument.uri,
          range = range.range,
        },
        ShowDocument = opts.show_document or false,
      },
    },
  }

  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.doc: " .. err.message, vim.log.levels.ERROR)
      return
    end
    if opts.show_document then
      vim.notify("Gopls doc opened in browser.", vim.log.levels.INFO)
    else
      -- copy result to clipboard
      vim.fn.setreg("+", result)
      vim.notify("Gopls doc URL copied to clipboard.", vim.log.levels.INFO)
    end
  end)
end

M.tidy = function()
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local params = {
    command = "gopls.tidy",
    arguments = {
      { URIs = { vim.uri_from_bufnr(bufnr) } },
    },
  }

  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.tidy: " .. err.message, vim.log.levels.ERROR)
    else
      vim.notify("Gopls tidy completed.", vim.log.levels.INFO)
    end
  end)
end

M.vendor = function()
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local params = {
    command = "gopls.vendor",
    arguments = {
      { URIs = { vim.uri_from_bufnr(bufnr) } },
    },
  }

  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.vendor: " .. err.message, vim.log.levels.ERROR)
    else
      vim.notify("Gopls vendor completed.", vim.log.levels.INFO)
    end
  end)
end

return M
