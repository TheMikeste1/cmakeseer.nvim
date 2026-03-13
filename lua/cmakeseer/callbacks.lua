local CMakeApi = require("cmakeseer.cmake.api")
local CMakeSeer = require("cmakeseer")
local CTestApi = require("cmakeseer.ctest.api")
local ObjectKind = require("cmakeseer.cmake.api.object_kind").Kind

local function load_targets()
  local build_dir = CMakeSeer.get_build_directory()
  local responses = CMakeApi.read_responses(build_dir)
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

  ---@cast codemodel_reference cmakeseer.cmake.api.ReplyFileReference

  local codemodel = CMakeApi.parse_object_kind_file(codemodel_reference, build_dir)
  if codemodel == nil then
    vim.notify("Codemodel file invalid. Cannot find targets. File: `" .. codemodel_reference.jsonFile .. "`", vim.log.levels.ERROR)
    return
  end

  assert(codemodel.kind == ObjectKind.codemodel)
  ---@cast codemodel cmakeseer.cmake.api.codemodel.CodeModel

  if #codemodel.configurations == 0 then
    vim.notify("No configurations exist in CMake codemodel: `" .. codemodel_reference.jsonFile .. "`", vim.log.levels.ERROR)
    return
  end

  -- TODO: Support multiple configurations
  local configuration = codemodel.configurations[1]
  local target_references = configuration.targets
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  local parsed_targets = {}
  for _, reference in ipairs(target_references) do
    local target = require("cmakeseer.cmake.api.codemodel.target").parse(reference, build_dir)
    if target == nil then
      vim.notify(string.format("JSON file for %s target not valid", reference.name), vim.log.levels.WARN)
    else
      table.insert(parsed_targets, target)
    end
  end

  require("cmakeseer.state").set_targets(parsed_targets)

  vim.notify(string.format("Found %i targets", #parsed_targets))
end

local function load_ctest_info()
  local maybe_info = CTestApi.issue_query(CMakeSeer.get_build_directory())
  if type(maybe_info) == "table" then
    require("cmakeseer.state").set_ctest_info(maybe_info)
    return
  end

  if maybe_info == CTestApi.IssueQueryError.NotConfigured then
    vim.notify("Unable to load CTest info: NotConfigured", vim.log.levels.ERROR)
    return
  end
  if maybe_info == CTestApi.IssueQueryError.NotCTestProject then
    vim.notify("Unable to load CTest info: NotCTestProject", vim.log.levels.ERROR)
    return
  end
  if maybe_info == CTestApi.IssueQueryError.SpawnProcess then
    vim.notify("Unable to load CTest info: SpawnProcess", vim.log.levels.ERROR)
    return
  end
  if maybe_info == CTestApi.IssueQueryError.InvalidJson then
    vim.notify("Unable to load CTest info: InvalidJson", vim.log.levels.ERROR)
    return
  end
  if maybe_info == CTestApi.IssueQueryError.InvalidCTestInfo then
    vim.notify("Unable to load CTest info: InvalidCTestInfo", vim.log.levels.ERROR)
    return
  end

  error("Unreachable")
end

local M = {}

--- Called before the project is configured.
function M.on_pre_configure()
  local maybe_error = CMakeApi.issue_query(ObjectKind.codemodel, CMakeSeer.get_build_directory())
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

function M.on_post_configure_success()
  load_targets()

  if CMakeSeer.is_ctest_project() then
    load_ctest_info()
  end
end

return M
