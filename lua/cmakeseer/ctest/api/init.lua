local ObjectKind = require("cmakeseer.cmake.api.object_kind")

local M = {
  --- @enum IssueQueryError The possible types of errors that could be produced when issuing a query.
  IssueQueryError = {
    NotConfigured = 0,
    NotCTestProject = 1,
    SpawnProcess = 2,
    InvalidJson = 3,
    InvalidCTestInfo = 4,
  },
}

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
  return vim.fn.glob(vim.fs.joinpath(build_directory, "CTestTestfile.cmake")) == ""
end

return M
