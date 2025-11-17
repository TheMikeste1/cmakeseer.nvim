local CMakeApi = require("cmakeseer.cmake.api")
local CTestApi = require("cmakeseer.ctest.api")
local Cmakeseer = require("cmakeseer")
local ObjectKind = require("cmakeseer.cmake.api.object_kind").Kind
local Target = require("cmakeseer.cmake.api.codemodel.target")

local function load_targets()
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

  ---@cast codemodel_reference cmakeseer.cmake.api.ReplyFileReference

  local codemodel = CMakeApi.parse_object_kind_file(codemodel_reference, Cmakeseer.get_build_directory())
  if codemodel == nil then
    vim.notify(
      "Codemodel file invalid. Cannot find targets. File: `" .. codemodel_reference.jsonFile .. "`",
      vim.log.levels.ERROR
    )
    return
  end

  assert(codemodel.kind == ObjectKind.codemodel)
  ---@cast codemodel cmakeseer.cmake.api.codemodel.CodeModel

  if #codemodel.configurations == 0 then
    vim.notify(
      "No configurations exist in CMake codemodel: `" .. codemodel_reference.jsonFile .. "`",
      vim.log.levels.ERROR
    )
    return
  end

  -- TODO: Support multiple configurations
  local configuration = codemodel.configurations[1]
  local target_references = configuration.targets
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  local parsed_targets = {}
  for _, reference in ipairs(target_references) do
    local target = Target.parse(reference, Cmakeseer.get_build_directory())
    if target == nil then
      vim.notify(string.format("JSON file for %s target not valid", reference.name), vim.log.levels.WARN)
    else
      table.insert(parsed_targets, target)
    end
  end

  Cmakeseer.__targets = parsed_targets

  vim.notify(string.format("Found %i targets", #parsed_targets))
end

local function load_ctest_info()
  local maybe_info = CTestApi.issue_query(Cmakeseer.get_build_directory())
  if type(maybe_info) == "table" then
    Cmakeseer.__ctest_info = maybe_info
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

function M.on_post_configure_success()
  load_targets()

  if Cmakeseer.is_ctest_project() then
    load_ctest_info()
  end
end

--- Runs the user's preconfigure callback.
function M.run_user_preconfigure()
  for _, callback in ipairs(Cmakeseer.callbacks().preconfigure) do
    local success, maybe_error = pcall(callback)
    if not success then
      vim.notify(
        string.format("User preconfigure callback failed with error: %s", vim.inspect(maybe_error)),
        vim.log.levels.ERROR
      )
    end
  end
end

--- Runs the user's postconfigure callback.
function M.run_user_postconfigure()
  for _, callback in ipairs(Cmakeseer.callbacks().postconfigure) do
    local success, maybe_error = pcall(callback)
    if not success then
      vim.notify(
        string.format("User postconfigure callback failed with error: %s", vim.inspect(maybe_error)),
        vim.log.levels.ERROR
      )
    end
  end
end

--- Runs the user's prebuild callback.
function M.run_user_prebuild()
  for _, callback in ipairs(Cmakeseer.callbacks().prebuild) do
    local success, maybe_error = pcall(callback)
    if not success then
      vim.notify(
        string.format("User prebuild callback failed with error: %s", vim.inspect(maybe_error)),
        vim.log.levels.ERROR
      )
    end
  end
end

--- Runs the user's postbuild callback.
function M.run_user_postbuild()
  for _, callback in ipairs(Cmakeseer.callbacks().postbuild) do
    local success, maybe_error = pcall(callback)
    if not success then
      vim.notify(
        string.format("User postbuild callback failed with error: %s", vim.inspect(maybe_error)),
        vim.log.levels.ERROR
      )
    end
  end
end

return M
