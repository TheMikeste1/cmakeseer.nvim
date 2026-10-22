local M = {}

--- Checks if this project uses CTest.
---@param build_directory string The path to the configured build directory.
---@return boolean
function M.is_ctest_project(build_directory)
  local path = vim.fs.joinpath(build_directory, "CTestTestfile.cmake")
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

return M
