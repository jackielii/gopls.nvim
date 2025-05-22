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

--- Lists Go package symbols in the current buffer in the |location-list|.
--- @param opts? vim.lsp.ListOpts
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

    local symbols = require("gopls.package_symbols").package_symbols_result_to_symbols(result)
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
      vim.fn.setloclist(0, {}, ' ', list)
      vim.cmd.lopen()
    else
      vim.fn.setqflist({}, ' ', list)
      vim.cmd('botright copen')
    end
  end)
end

return M
