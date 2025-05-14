local M = {}

function M.setup(opts) end

M.list_known_packages = function(bufnr)
	if bufnr == nil then
		bufnr = vim.api.nvim_get_current_buf() or 0
	end
	local gopls
	for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })) do
		if client.name == "gopls" then
			gopls = client
			break
		end
	end

	if gopls == nil then
		vim.notify("No gopls client found for the current buffer.", vim.log.levels.WARN)
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

return M
