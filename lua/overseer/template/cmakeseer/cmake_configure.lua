local function builder()
	local cwd = vim.fn.getcwd()
	---@type overseer.TaskDefinition
	return {
		name = "CMake Configure",
		cmd = "cmake",
		args = {
			"-B",
			cwd .. "/build",
			"-S",
			cwd,
		},
	}
end

---@type overseer.TemplateFileDefinition
return {
	name = "CMake Configure",
	desc = "Configure the current CMake projects",
	builder = builder,
	condition = {
		callback = function()
			return true
		end,
	},
}
