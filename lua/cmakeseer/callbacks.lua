local CMakeApi = require("cmakeseer.cmake.api")
local Cmakeseer = require("cmakeseer")
local ObjectKind = require("cmakeseer.cmake.api.model.object_kind").Kind

local M = {}

--- Called before the project is configured.
function M.onPreConfigure()
  local maybe_error = CMakeApi.issue_query(ObjectKind.codemodel, Cmakeseer.get_build_directory())
  if maybe_error ~= nil then
    local error_str = "Unknown error"
    if maybe_error == CMakeApi.IssueQueryError.failed_to_make_query_file then
      error_str = "Failed to make query file"
    elseif maybe_error == CMakeApi.IssueQueryError.failed_to_make_directory then
      error_str = "Failed to make query directory"
    end

    vim.notify("Failed to issue CMake query: " .. error_str, vim.log.levels.ERROR)
    return
  end
end

return M
