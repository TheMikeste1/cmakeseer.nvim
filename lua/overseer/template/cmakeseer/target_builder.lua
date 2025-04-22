---@module "overseer.template"

local Cmakeseer = require("cmakeseer")
local CmakeseerOverseerBuild = require("overseer.template.cmakeseer.cmake_build")
local TargetType = require("cmakeseer.cmake.api.codemodel.target").TargetType

local M = {}

--- Builds a TaskTemplate for the provided target.
---@param target_name string The target to build.
---@param target_type cmakeseer.cmake.api.codemodel.TargetType The type of the target.
---@return overseer.TemplateFileDefinition
function M.build_template_for(target_name, target_type)
  local run_verb = "Build"

  if target_type == TargetType.Utility then
    run_verb = "Run"
  end

  return {
    name = string.format("CMake %s `%s` (%s)", run_verb, target_name, target_type),
    desc = string.format("%ss the `%s` target", run_verb, target_name),
    --- @return overseer.TaskDefinition
    builder = function(params)
      local config = CmakeseerOverseerBuild.builder(params)
      config.name = string.format("CMake %s `%s` (%s)", run_verb, target_name, target_type)
      table.insert(config.args, "--target")
      table.insert(config.args, target_name)
      return config
    end,
    condition = {
      callback = Cmakeseer.project_is_configured,
    },
  }
end

return M
