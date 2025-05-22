local Mod = {}

---@param opts snacks.picker.lsp.symbols.Config
---@type snacks.picker.finder
Mod.package_symbols_finder = function(opts, ctx)
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

  -- local method = opts.workspace and "workspace/symbol" or "textDocument/documentSymbol"
  -- local p = opts.workspace and { query = ctx.filter.search }
  --   or { textDocument = vim.lsp.util.make_text_document_params(buf) }
  --- NOTE: CHANGED
  local method = vim.lsp.protocol.Methods.workspace_executeCommand
  local p = {
    command = "gopls.package_symbols",
    arguments = {
      { uri = vim.uri_from_bufnr(buf) },
    },
  }

  ---@async
  ---@param cb async fun(item: snacks.picker.finder.Item)
  return function(cb)
    M.request(buf, method, function()
      return p
    end, function(client, result, params)
      --- NOTE: ADDED
      local symbols = require("gopls.package_symbols").package_symbols_result_to_symbols(result)

      local items = M.results_to_items(client, symbols, {
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

Mod.list_package_symbols = function()
  local opts = require("snacks.picker.config.sources").lsp_symbols
  opts = vim.tbl_deep_extend("force", opts, {
    title = "Package Symbols",
    finder = Mod.package_symbols_finder,
  })
  require("snacks.picker").pick(opts)
end

return Mod
