local CMakeQuery = require("cmakeseer.cmake.file_api.query")
local cmake_reply = require("cmakeseer.cmake.file_api.reply")
local cmakeseer = require("cmakeseer")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType
local state = require("cmakeseer.state")

--- The configuration of a codemodel whose targets should be loaded.
---
--- Single configuration generators write a single configuration with an empty name, while multi
--- configuration generators write one configuration per build type. The selected variant names the
--- configuration to use for a multi configuration generator; when the generator has no configuration
--- with that name, the first one is used instead.
---@param codemodel cmakeseer.cmake.file_api.object_kind.Codemodel The codemodel to select a configuration from.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration? configuration The configuration to load targets from, or nil when the codemodel has none.
local function select_configuration(codemodel)
  local variant = state.selections.variant
  local configuration = codemodel.configurations[variant]
  if configuration ~= nil then
    return configuration
  end

  ---@type string?, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration?
  local _, first_configuration = next(codemodel.configurations)
  return first_configuration
end

---@param build_dir? string The build directory to load the targets from. Defaults to CMakeSeer's resolved build directory.
local function load_targets(build_dir)
  build_dir = build_dir or cmakeseer.resolve_build_directory()
  state.set_targets({})

  local latest_reply, err = cmake_reply.get_client_stateless_reply(build_dir, cmakeseer.CLIENT_ID, ObjectKindType.Codemodel, 2)
  if latest_reply == nil then
    vim.notify("Unable to load targets: " .. err, vim.log.levels.ERROR)
    return
  end

  if latest_reply.kind ~= "valid" then
    vim.notify("Unable to load targets: reply was " .. latest_reply.kind, vim.log.levels.ERROR)
    return
  end

  local codemodel
  codemodel, err = latest_reply.reply:try_load()
  if codemodel == nil then
    vim.notify("Unable to load targets: codemodel was invalid: " .. err, vim.log.levels.ERROR)
    return
  end
  assert(codemodel.kind == ObjectKindType.Codemodel, "Response should only be able to be a codemodel")
  ---@cast codemodel cmakeseer.cmake.file_api.object_kind.Codemodel

  local configuration = select_configuration(codemodel)
  if configuration == nil then
    vim.notify("No configurations exist in CMake codemodel: `" .. latest_reply.reply.json_file .. "`", vim.log.levels.ERROR)
    return
  end

  state.set_configuration_names(vim.tbl_keys(codemodel.configurations))

  local target_references = configuration.targets
  ---@type cmakeseer.cmake.file_api.object_kind.Codemodel.Target[]
  local targets = {}
  local num_failed_parse = 0
  for _, target in pairs(target_references) do
    local target_codemodel = target:try_read_codemodel()
    if target_codemodel == nil then
      num_failed_parse = num_failed_parse + 1
    else
      table.insert(targets, target_codemodel)
    end
  end

  if #targets ~= #state.targets() then
    vim.notify(string.format("Found %i targets", #targets))
  end
  if num_failed_parse > 0 then
    vim.notify(("Failed to parse %d targets"):format(num_failed_parse), vim.log.levels.WARN)
  end

  state.set_targets(targets)
end

local M = {}

--- Called before the project is configured.
---@param build_dir? string The build directory to issue the query in. Defaults to CMakeSeer's resolved build directory.
function M.on_pre_configure(build_dir)
  build_dir = build_dir or cmakeseer.resolve_build_directory()
  local maybe_error = CMakeQuery.issue_client_stateless_query(cmakeseer.CLIENT_ID, build_dir, ObjectKindType.Codemodel, 2)
  if maybe_error ~= nil then
    vim.notify("Failed to issue CMake query: " .. maybe_error, vim.log.levels.ERROR)
  end
end

--- Called after the project is configured successfully.
---@param build_dir? string The build directory to load the targets from. Defaults to CMakeSeer's resolved build directory.
function M.on_post_configure_success(build_dir)
  load_targets(build_dir)
end

return M
