local cmakeseer = require("cmakeseer")

local function builder()
	---@type overseer.TaskDefinition
	return {
		name = "CMake Configure",
		cmd = cmakeseer.get_configure_command()
	}
end

---@type overseer.TemplateFileDefinition
return {
	name = "CMake Configure",
	desc = "Configure the current CMake projects",
	builder = builder,
	condition = {
		callback = function()
			return vim.fn.filereadable(vim.fn.getcwd() .. "/CMakeLists.txt") ~= 0
		end,
	},
}
