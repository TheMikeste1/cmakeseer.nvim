local function builder()
	---@type overseer.TaskDefinition
	return {
		name = "CMake Clean",
		cmd = "cmake",
		args = {
			"--build",
			vim.fn.getcwd() .. "/build",
			"--target",
			"clean",
		},
	}
end

---@type overseer.TemplateFileDefinition
return {
	name = "CMake Clean",
	desc = "Cleans the CMake build directory",
	builder = builder,
	condition = {
		callback = function()
			return true
		end,
	},
}
