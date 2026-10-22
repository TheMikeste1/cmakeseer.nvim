local CMakeQuery = require("cmakeseer.cmake.file_api.query")
local cmake_reply = require("cmakeseer.cmake.file_api.reply")
local cmakeseer = require("cmakeseer")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

local function load_targets()
  local state = require("cmakeseer.state")
  state.set_targets({})

  local build_dir = cmakeseer.resolve_build_directory()
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

  if vim.tbl_isempty(codemodel.configurations) then
    vim.notify("No configurations exist in CMake codemodel: `" .. latest_reply.reply.json_file .. "`", vim.log.levels.ERROR)
    return
  end

  -- TODO: Support multiple configurations
  ---@type string,cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
  local _, configuration = assert(next(codemodel.configurations))
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
function M.on_pre_configure()
  local maybe_error = CMakeQuery.issue_client_stateless_query(cmakeseer.CLIENT_ID, cmakeseer.resolve_build_directory(), ObjectKindType.Codemodel, 2)
  if maybe_error ~= nil then
    vim.notify("Failed to issue CMake query: " .. maybe_error, vim.log.levels.ERROR)
  end
end

function M.on_post_configure_success()
  load_targets()
end

return M
