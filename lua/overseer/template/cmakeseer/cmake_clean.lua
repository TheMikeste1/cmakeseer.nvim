local cmakeseer = require("cmakeseer")

local function builder()
	---@type overseer.TaskDefinition
	return {
		name = "CMake Clean",
		cmd = "cmake",
		args = {
			"--build",
			cmakeseer.get_build_directory(),
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
			return cmakeseer.project_is_configured()
		end,
	},
}
