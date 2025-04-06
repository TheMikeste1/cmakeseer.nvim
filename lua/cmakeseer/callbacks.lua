local CMakeApi = require("cmakeseer.cmake.api")
local Cmakeseer = require("cmakeseer")
local ObjectKind = require("cmakeseer.cmake.api.model.object_kind").Kind

local M = {}

--- Called before the project is configured.
function M.onPreConfigure()
  local maybe_error = CMakeApi.issue_query(ObjectKind.codemodel, Cmakeseer.get_build_directory())
  if maybe_error ~= nil then
    local error_str = "Unknown error"
    if maybe_error == CMakeApi.IssueQueryError.FailedToMakeQueryFile then
      error_str = "Failed to make query file"
    elseif maybe_error == CMakeApi.IssueQueryError.FailedToMakeDirectory then
      error_str = "Failed to make query directory"
    end

    vim.notify("Failed to issue CMake query: " .. error_str, vim.log.levels.ERROR)
    return
  end
end

function M.onPostConfigureSuccess()
  local responses = CMakeApi.read_responses(Cmakeseer.get_build_directory())
  local codemodel_reference = nil
  for _, response in ipairs(responses) do
    if response.kind == ObjectKind.codemodel then
      codemodel_reference = response
      break
    end
  end

  if codemodel_reference == nil then
    return
  end

  ---@cast codemodel_reference ReplyFileReference

  local codemodel = CMakeApi.parse_object_kind_file(codemodel_reference, Cmakeseer.get_build_directory())
  if codemodel == nil then
    vim.notify(
      "Codemodel file does not exist. Cannot find targets. File: `" .. codemodel_reference.json_file .. "`",
      vim.log.levels.ERROR
    )
    return
  end

  assert(codemodel.kind == ObjectKind.codemodel)
  ---@cast codemodel CodeModel

  -- TODO: Support multiple configurations
  local configuration = codemodel.configurations[1]
  -- TODO: Parse target files and create list of targets.
end

return M
