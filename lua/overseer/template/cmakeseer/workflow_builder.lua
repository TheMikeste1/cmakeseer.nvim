---@module "overseer.template"

local M = {}

--- Builds a TaskTemplate for the provided workflow preset.
---@param preset string The preset to build.
---@return overseer.TemplateFileDefinition
function M.build_template_for(preset)
  local CMakeSeer = require("cmakeseer")
  local Presets = require("cmakeseer.cmake.preset")

  local entry = Presets.entry_for(preset, CMakeSeer.get_config().project_root(), Presets.Types.Workflow)
  ---@cast entry cmakeseer.cmake.preset.WorkflowPreset
  local name = entry.display_name or entry.name
  local desc = entry.description or ("Runs the `%s` workflow"):format(preset)
  return {
    name = ("CMake Workflow %s"):format(name),
    desc = desc,
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
