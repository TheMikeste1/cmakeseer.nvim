---@module "overseer.template"

local M = {}

--- Builds a TaskTemplate for the provided workflow preset.
---@param preset string The preset to build.
---@return overseer.TemplateFileDefinition
function M.build_template_for(preset)
  local CMakeSeer = require("cmakeseer")

  -- TODO: Use the displayName of the preset, if it exists. Maybe use the description too.
  return {
    name = ("CMake Workflow %s"):format(preset),
    desc = ("Runs the `%s` workflow"):format(preset),
    --- @return overseer.TaskDefinition
    builder = function()
      return {
        name = ("CMake Workflow %s"):format(preset),
        cmd = CMakeSeer.get_config().cmake_command,
        args = { "--workflow", "--preset", preset },
        components = {
          -- TODO: We don't really know what this workflow will do. . . We ought to fire our hooks,
          -- but we first need to know where it's configuring/building
          {
            "unique",
            restart_interrupts = false,
          },
          "default",
        },
      }
    end,
  }
end

return M
