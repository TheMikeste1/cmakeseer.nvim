local function builder()
	local cwd = vim.fn.getcwd()
	local build_dir = cwd .. "/build"

	---@type overseer.TaskDefinition
	local task = {
		name = "CMake Build",
		cmd = "cmake --build " .. build_dir,
		components = {
			{
				"unique",
				restart_interrupts = false,
			},
			"default",
		},
	}

	if vim.fn.filereadable(build_dir .. "/CMakeCache.txt") == 0 then
		-- Insert just before "default" to minimize shifts
		table.insert(task.components, #task.components - 1, {
			"dependencies",
			task_names = {
				require("overseer.template.cmakeseer.cmake_configure").name,
			},
		})
	end

	return task
end

---@type overseer.TemplateFileDefinition
return {
	name = "CMake Build",
	desc = "Builds all targets in the current CMake project, configuring the project if it isn't already",
	builder = builder,
	condition = {
		callback = function()
			return true
		end,
	},
}
