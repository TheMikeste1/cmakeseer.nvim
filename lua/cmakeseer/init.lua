local M = {}

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

return M
