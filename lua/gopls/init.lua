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

M.list_known_packages = function()
  local bufnr = vim.api.nvim_get_current_buf() or 0
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
--- @field show_gopkg boolean? : Show the documentation in https://pkg.go.dev/

--- @param opts? gopls.doc.Config
M.doc = function(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end
  local range = vim.lsp.util.make_range_params(0, gopls.offset_encoding)
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

  local function convert_gopls_url(url)
    -- Strip the query string (everything after ? but before #)
    local base = url:match("^[^%?]+") or url

    -- Extract fragment if present
    local fragment = url:match("#(.+)$")
    fragment = fragment and ("#" .. fragment) or ""

    -- Extract Go package path after /pkg/
    local path = base:match("/pkg/(.+)")
    if not path then
      vim.notify("gopls.doc: No valid package path found in URL: " .. url, vim.log.levels.WARN)
      return nil
    end

    -- Compose pkg.go.dev URL
    return "https://pkg.go.dev/" .. path .. fragment
  end

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.doc: " .. err.message, vim.log.levels.ERROR)
      return
    end
    if opts.show_document then
      vim.notify("Gopls doc opened in browser.", vim.log.levels.INFO)
    elseif opts.show_gopkg then
      local url = convert_gopls_url(result)
      M.client_open_url(url)
    else
      -- copy result to clipboard
      vim.fn.setreg("+", result)
      vim.notify("Gopls doc URL copied to clipboard.", vim.log.levels.INFO)
    end
  end)
end

M.tidy = function()
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end
  local params = {
    command = "gopls.tidy",
    arguments = {
      { URIs = { vim.uri_from_bufnr(bufnr) } },
    },
  }

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
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end
  local params = {
    command = "gopls.vendor",
    arguments = {
      { URIs = { vim.uri_from_bufnr(bufnr) } },
    },
  }

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.vendor: " .. err.message, vim.log.levels.ERROR)
    else
      vim.notify("Gopls vendor completed.", vim.log.levels.INFO)
    end
  end)
end

M.add_test = function()
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  local range = vim.lsp.util.make_range_params(0, gopls.offset_encoding)
  local params = {
    command = "gopls.add_test",
    arguments = {
      {
        uri = range.textDocument.uri,
        range = range.range,
      },
    },
  }

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.add_test: " .. err.message, vim.log.levels.ERROR)
      return
    end
    -- vim.lsp.util.apply_workspace_edit(result.Edit)
    vim.notify("Gopls add_test completed.", vim.log.levels.INFO)
  end)
end

--- @param opts? gopls.go_get_package.Config
--- @class gopls.go_get_package.Config
--- @field add_require boolean? : Whether to add the package to go.mod as a require statement
--- @field import_path string? : The import path of the package to get
--- @field add_import boolean? : Whether to add the import to the current file
M.go_get_package = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { add_require = true })
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  local input
  if opts.import_path then
    -- If import_path is provided, use it directly
    input = function(_, callback)
      callback(opts.import_path)
    end
  else
    -- Otherwise, prompt the user for input
    input = function(prompt, callback)
      vim.ui.input({ prompt = prompt }, callback)
    end
  end

  input("Enter package import path: ", function(import_path)
    -- trim whitespace from the input
    import_path = import_path:match("^%s*(.-)%s*$")
    -- trim surrounding quotes if present
    import_path = import_path:gsub('^"(.-)"$', "%1"):gsub("^'(.-)'$", "%1")

    if not import_path or import_path == "" then
      vim.notify("No import path provided.", vim.log.levels.WARN)
      return
    end

    local params = {
      command = "gopls.go_get_package",
      arguments = {
        { URI = vim.uri_from_bufnr(bufnr), Pkg = import_path, AddRequire = opts.add_require },
      },
    }

    gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
      if err then
        vim.notify("Error running gopls.go_get_package: " .. err.message, vim.log.levels.ERROR)
        return
      end

      if opts.add_import then
        M.add_import(import_path)
      end
    end)
  end)
end

M.diagnose_files = function(...)
  if #... == 0 then
    vim.notify("No files provided for gopls.diagnose_files", vim.log.levels.WARN)
    return
  end
  local gopls = get_gopls_client(nil)
  if not gopls then
    return
  end
  local uris = {}
  for _, fname in ipairs({ ... }) do
    table.insert(uris, vim.uri_from_fname(fname))
  end
  local params = {
    command = "gopls.diagnose_files",
    arguments = { { Files = uris } },
  }
  gopls:exec_cmd(params, {}, function(err, result)
    if err then
      vim.notify("Error reloading file: " .. err.message, vim.log.levels.ERROR)
    else
      vim.notify("Notified gopls for " .. uris[1])
    end
  end)
end

-- type AddImportArgs struct {
-- 	// ImportPath is the target import path that should
-- 	// be added to the URI file
-- 	ImportPath string
-- 	// URI is the file that the ImportPath should be
-- 	// added to
-- 	URI protocol.DocumentURI
-- }
M.add_import = function(import_path)
  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  if not import_path or import_path == "" then
    vim.notify("No import path provided.", vim.log.levels.WARN)
    return
  end

  local params = {
    command = "gopls.add_import",
    arguments = {
      { ImportPath = import_path, URI = vim.uri_from_bufnr(bufnr) },
    },
  }

  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.add_import: " .. err.message, vim.log.levels.ERROR)
      return
    end

    if result and result.success then
      vim.notify("Import added successfully.", vim.log.levels.INFO)
    else
      vim.notify("Failed to add import.", vim.log.levels.ERROR)
    end
  end)
end

M.client_open_url = function(url)
  if not url or url == "" then
    vim.notify("gopls.client_open_url: No URL provided.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  local params = {
    command = "gopls.client_open_url",
    arguments = { url },
  }
  gopls:exec_cmd(params, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.client_open_url: " .. err.message, vim.log.levels.ERROR)
      return
    end
  end)
end

return M
