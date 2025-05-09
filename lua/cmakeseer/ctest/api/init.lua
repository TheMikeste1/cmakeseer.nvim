local ObjectKind = require("cmakeseer.cmake.api.object_kind")

local M = {
  --- @enum cmakeseer.ctest.api.IssueQueryError The possible types of errors that could be produced when issuing a query.
  IssueQueryError = {
    NotConfigured = 0,
    NotCTestProject = 1,
    SpawnProcess = 2,
    InvalidJson = 3,
    InvalidCTestInfo = 4,
  },
}

--- Issue a query to the CMake file API.
---@param build_directory string The directory in which the CMake project will be configured.
---@return cmakeseer.cmake.api.CTestInfo|cmakeseer.ctest.api.IssueQueryError maybe_error The CTestInfo response, or an error, if one occurs.
function M.issue_query(build_directory)
  if not vim.fn.glob(build_directory) then
    return M.IssueQueryError.NotConfigured
  end

  if not M.is_ctest_project(build_directory) then
    return M.IssueQueryError.NotCTestProject
  end

  local handle = io.popen(string.format("ctest --test-dir '%s' --show-only=json-v1", build_directory), "r")
  if handle == nil then
    return M.IssueQueryError.SpawnProcess
  end

  local result = handle:read("a")
  handle:close()

  local success, json = pcall(vim.fn.json_decode, result)
  if not success then
    return M.IssueQueryError.InvalidJson
  end

  if not ObjectKind.is_valid(json, ObjectKind.Kind.ctest_info) then
    return M.IssueQueryError.InvalidCTestInfo
  end

  return json
end

function M.is_ctest_project(build_directory)
  local path = vim.fs.joinpath(build_directory, "CTestTestfile.cmake")
  return vim.fn.glob(path) ~= ""
end

return M
