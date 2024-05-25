local function builder()
	local cwd = vim.fn.getcwd()
	local build_dir = cwd .. "/build"

	---@type overseer.TaskDefinition
	return {
		name = "CMake Build",
		cmd = "cmake -B " .. build_dir .. " -S " .. cwd .. " && cmake --build " .. build_dir,
	}
end

---@type overseer.TemplateFileDefinition
return {
	name = "CMake Build",
	desc = "Builds all  targets in the current CMake project",
	builder = builder,
	condition = {
		callback = function()
			return true
		end,
	},
}
