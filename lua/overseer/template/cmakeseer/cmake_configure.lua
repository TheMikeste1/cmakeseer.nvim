local cmakeseer = require("cmakeseer")

local function builder()
	local args = {
		"-S",
		vim.fn.getcwd(),
		"-B",
		cmakeseer.get_build_directory(),
	}
	if cmakeseer.selected_kit == nil then
		-- If a kit isn't selected, we'll just select the first
		if #cmakeseer.kits >= 1 then
			cmakeseer.selected_kit = cmakeseer.kits[1]
			vim.notify_once("No kit selected; selecting " .. cmakeseer.selected_kit.name, vim.log.levels.INFO)
		else
			vim.notify_once(
				"Could not find a kit; not specifying compilers in CMake configuration",
				vim.log.levels.WARN
			)
		end
	end

	if cmakeseer.selected_kit ~= nil then
		vim.tbl_extend(args, {
			"-DCMAKE_C_COMPILER:FILEPATH=" .. cmakeseer.selected_kit.compilers.C,
			"-DCMAKE_CXX_COMPILER:FILEPATH=" .. cmakeseer.selected_kit.compilers.CXX,
		})
	end

	---@type overseer.TaskDefinition
	return {
		name = "CMake Configure",
		cmd = "cmake",
		args = args,
		components = {
			{
				"unique",
				restart_interrupts = false,
			},
			"default",
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
			return vim.fn.filereadable(vim.fn.getcwd() .. "/CMakeLists.txt") ~= 0
		end,
	},
}
