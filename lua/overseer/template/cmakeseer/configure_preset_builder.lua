---@module "overseer.template"

local M = {}

--- Builds a TaskTemplate for the provided preset.
---@param preset string The name of the preset.
---@param use_basic_args boolean? If the template should only use basic args instead of all configured args.
---@return overseer.TemplateFileDefinition
function M.build_template_for(preset, use_basic_args)
  local CmakeseerOverseerConfigure = require("overseer.cmakeseer.template.cmake_configure")

  local name = string.format("CMake Configure Preset `%s`%s", preset, use_basic_args and " [no defines]" or "")
  return {
    name = name,
    desc = string.format("Configures using the `%s` preset", preset),
    --- @param params table The parameters to the builder.
    --- @return overseer.TaskDefinition
    builder = function(params)
      local config = CmakeseerOverseerConfigure.builder(params)
      config.name = name
      if use_basic_args then
        config.args = require("cmakeseer").get_basic_configure_args()
      end

      table.insert(config.args, "--preset")
      table.insert(config.args, preset)
      return config
    end,
  }
end

return M
