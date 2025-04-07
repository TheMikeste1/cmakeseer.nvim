local Cmakeseer = require("cmakeseer")
local CmakeseerOverseerBuild = require("overseer.template.cmakeseer.cmake_build")

local M = {}

--- Builds a TaskTemplate for the provided target.
---@param target_name string The target to build.
---@param target_type TargetType The type of the target.
---@return overseer.TemplateFileDefinition
function M.build_template_for(target_name, target_type)
  return {
    name = string.format("CMake Build `%s` (%s)", target_name, target_type),
    desc = string.format("Builds the `%s` target", target_name),
    --- @return overseer.TaskDefinition
    builder = function(params)
      local config = CmakeseerOverseerBuild.builder(params)
      config.name = string.format("CMake Build `%s` (%s)", target_name, target_type)
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
