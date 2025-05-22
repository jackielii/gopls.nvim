local M = {}

--- Copied from Gopls's definition:
--- https://github.com/golang/tools/blob/master/gopls/internal/protocol/command/interface.go#L806-L835
-- type PackageSymbolsResult struct {
-- 	PackageName string
-- 	// Files is a list of files in the given URI's package.
-- 	Files   []protocol.DocumentURI
-- 	Symbols []PackageSymbol
-- }
--
-- // PackageSymbol has the same fields as DocumentSymbol, with an additional int field "File"
-- // which stores the index of the symbol's file in the PackageSymbolsResult.Files array
-- type PackageSymbol struct {
-- 	Name string `json:"name"`
--
-- 	Detail string `json:"detail,omitempty"`
--
-- 	// protocol.SymbolKind maps an integer to an enum:
-- 	// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#symbolKind
-- 	// i.e. File = 1
-- 	Kind protocol.SymbolKind `json:"kind"`
--
-- 	Tags []protocol.SymbolTag `json:"tags,omitempty"`
--
-- 	Range protocol.Range `json:"range"`
--
-- 	SelectionRange protocol.Range `json:"selectionRange"`
--
-- 	Children []PackageSymbol `json:"children,omitempty"`
--
-- 	// Index of this symbol's file in PackageSymbolsResult.Files
-- 	File int `json:"file,omitempty"`
-- }
--- @class PackageSymbolsResult
--- @field PackageName string
--- @field Files lsp.DocumentUri[]
--- @field Symbols PackageSymbol[]
---
--- @class PackageSymbol
--- @field name string
--- @field detail string?
--- @field kind lsp.SymbolKind
--- @field tags lsp.SymbolTag[]
--- @field range lsp.Range
--- @field selectionRange lsp.Range
--- @field children PackageSymbol[]
--- @field file integer

--- @param parent string
--- @param files lsp.DocumentUri[]
--- @param symbols PackageSymbol[]
--- @return lsp.DocumentSymbol[]
local function package_symbols_to_symbols(parent, files, symbols)
  local result = {}
  for _, symbol in ipairs(symbols) do
    local doc_symbol = {
      name = symbol.name,
      parent_name = parent,
      detail = symbol.detail,
      kind = symbol.kind,
      tags = symbol.tags,
      range = symbol.range,
      location = {
        -- here we use location instead of selectionRange, why?
        -- DocumentSymbol is only for a single file, but it has children which our PackageSymbol also contains
        -- here we combined the DocumentSymbol and SymbolInformation check vim.lsp.util.symbols_to_items for details
        uri = files[(symbol.file or 0) + 1], -- file is 0-indexed
        range = symbol.selectionRange,
      },
      -- selectionRange = symbol.selectionRange,
    }

    if symbol.children and #symbol.children > 0 then
      doc_symbol.children = package_symbols_to_symbols(doc_symbol.name, files, symbol.children)
    end

    table.insert(result, doc_symbol)
  end

  return result
end

--- @param result PackageSymbolsResult
--- @return lsp.DocumentSymbol[]
M.package_symbols_result_to_symbols = function(result)
  return package_symbols_to_symbols(result.PackageName, result.Files, result.Symbols)
end

return M
