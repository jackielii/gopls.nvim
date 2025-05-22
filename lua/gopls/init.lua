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

      local add_import_command = {
        command = "gopls.add_import",
        arguments = {
          { uri = vim.uri_from_bufnr(bufnr), ImportPath = selected },
        },
      }
      gopls:exec_cmd(add_import_command, { bufnr = bufnr }, function(err, result)
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

M.list_package_symbols = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf() or 0
  local gopls = get_gopls_client(bufnr)
  if not gopls then
    return
  end

  local command = {
    command = "gopls.package_symbols",
    arguments = {
      { uri = vim.uri_from_bufnr(0) },
    },
  }

  gopls:exec_cmd(command, { bufnr = bufnr }, function(err, result)
    if err then
      vim.notify("Error running gopls.list_known_packages: " .. err.message, vim.log.levels.ERROR)
      return
    end
    Snacks.pick(snacks_picker_opts)
  end)
end

---@param opts snacks.picker.lsp.config.Config
---@type snacks.picker.finder
M.package_symbols_finder = function(opts, ctx)
  local M = require("snacks.picker.source.lsp")

  local buf = ctx.filter.current_buf
  -- For unloaded buffers, load the buffer and
  -- refresh the picker on every LspAttach event
  -- for 10 seconds. Also defer to ensure the file is loaded by the LSP.
  if not vim.api.nvim_buf_is_loaded(buf) then
    local id = vim.api.nvim_create_autocmd("LspAttach", {
      buffer = buf,
      callback = vim.schedule_wrap(function()
        if ctx.picker:count() > 0 then
          return true
        end
        ctx.picker:find()
        vim.defer_fn(function()
          if ctx.picker:count() == 0 then
            ctx.picker:find()
          end
        end, 1000)
      end),
    })
    pcall(vim.fn.bufload, buf)
    vim.defer_fn(function()
      vim.api.nvim_del_autocmd(id)
    end, 10000)
    return function()
      ctx.async:sleep(2000)
    end
  end

  local bufmap = M.bufmap()
  local filter = opts.filter[vim.bo[buf].filetype]
  if filter == nil then
    filter = opts.filter.default
  end
  ---@param kind string?
  local function want(kind)
    kind = kind or "Unknown"
    return type(filter) == "boolean" or vim.tbl_contains(filter, kind)
  end

  local method = vim.lsp.protocol.Methods.workspace_executeCommand
  local params = function()
    return {
      command = "gopls.package_symbols",
      arguments = {
        { uri = vim.uri_from_bufnr(buf) },
      },
    }
  end
  -- local method = opts.workspace and "workspace/symbol" or "textDocument/documentSymbol"
  local p = opts.workspace and { query = ctx.filter.search }
    or { textDocument = vim.lsp.util.make_text_document_params(buf) }

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    M.request(buf, method, params, function(client, result, params)
      local items = M.results_to_items(client, result, {
        default_uri = params.textDocument and params.textDocument.uri or nil,
        text_with_file = opts.workspace,
        filter = function(item)
          return want(M.symbol_kind(item.kind))
        end,
      })

      -- Fix sorting
      if not opts.workspace then
        table.sort(items, function(a, b)
          if a.pos[1] == b.pos[1] then
            return a.pos[2] < b.pos[2]
          end
          return a.pos[1] < b.pos[1]
        end)
      end

      -- fix last
      local last = {} ---@type table<snacks.picker.finder.Item, snacks.picker.finder.Item>
      for _, item in ipairs(items) do
        item.last = nil
        local parent = item.parent
        if parent then
          if last[parent] then
            last[parent].last = nil
          end
          last[parent] = item
          item.last = true
        end
      end

      for _, item in ipairs(items) do
        item.tree = opts.tree
        item.buf = bufmap[item.file]
        ---@diagnostic disable-next-line: await-in-sync
        cb(item)
      end
    end)
  end
end

M.list_package_symbols_snacks = function()
  local opts = require("snacks.picker.config.sources").lsp_symbols
  opts = vim.tbl_deep_extend("force", opts, {
    finder = M.package_symbols_finder,
  })
  require("snacks.picker").pick(opts)
end

return M
