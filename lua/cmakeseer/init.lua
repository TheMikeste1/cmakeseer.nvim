local M = {
	---@type cmakeseer.Kit[]
	kits = {},
	---@type cmakeseer.Kit
	selected_kit = nil,
}

---@return string build_dir The project's build directory.
function M.get_build_directory()
	return vim.fn.getcwd() .. "/build"
end

---@return boolean is_configured If the project is configured.
function M.project_is_configured()
	return vim.fn.filereadable(M.get_build_directory() .. "/CMakeCache.txt") ~= 0
end

---@return string build_cmd The command used to build the CMake project.
function M.get_build_command()
	return "cmake --build " .. M.get_build_directory()
end

---@return string configure_command The command used to configure the CMake project.
function M.get_configure_command()
	return "cmake -S " .. vim.fn.getcwd() .. " -B " .. M.get_build_directory()
end

---@return cmakeseer.Kit[] kits The kits
function M.read_cmakekit_file()
	local file_path = vim.fn.expand("~/.local/share/CMakeTools/cmake-tools-kits.json")
	if vim.fn.filereadable(file_path) == 0 then
		return {}
	end

	local file = io.open(file_path, "r")
	if file == nil then
		return {}
	end

	local file_contents = file:read("a")
	---@type cmakeseer.Kit[]
	local kits = vim.json.decode(file_contents)
	file:close()
	return kits
end

--- Select a kit to use
function M.select_kit()
	M.kits = M.read_cmakekit_file()
	vim.ui.select(
		M.kits,
		{
			prompt = "Select kit",
			---@param item cmakeseer.Kit
			---@return string
			format_item = function(item)
				vim.print(item)
				local c_compiler = item.compilers.C
				if #c_compiler > 20 then
					c_compiler = vim.fn.pathshorten(c_compiler)
				end

				local cxx_compiler = item.compilers.CXX
				if #cxx_compiler > 20 then
					cxx_compiler = vim.fn.pathshorten(cxx_compiler)
				end
				return item.name .. " (" .. c_compiler .. ", " .. cxx_compiler .. ")"
			end,
		},
		---@param choice cmakeseer.Kit
		function(choice)
			M.selected_kit = choice
		end
	)
end

return M
