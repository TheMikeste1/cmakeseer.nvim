---@module "overseer"

--- @param params table The parameters to the builder.
--- @return overseer.TaskDefinition
local function builder(params)
  params.target = params.target or "all"

  local config = require("overseer.cmakeseer.template.cmake_build").builder(params)
  config.name = string.format("CMake Build %s", params.target)
  table.insert(config.args, "--target")
  table.insert(config.args, params.target)
  return config
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Build Target",
  desc = "Builds a specific targets in the current CMake project, configuring the project if it isn't already",
  params = function()
    local CMakeSeer = require("cmakeseer")
    local target_choices = { "all" }
    for _, target_ref in ipairs(CMakeSeer.state.get_targets()) do
      table.insert(target_choices, target_ref.name)
    end

    ---@type overseer.Params
    return {
      ---@type overseer.EnumParam
      target = {
        name = "target",
        desc = "The target to build",
        type = "enum",
        choices = target_choices,
        validate = function(value)
          if value == "all" then
            return true
          end

          for _, target in ipairs(CMakeSeer.state.get_targets()) do
            if value == target.name then
              return true
            end
          end
          return false
        end,
      },
    }
  end,
  builder = builder,
  condition = {
    callback = function()
      return require("cmakeseer").project_is_configured()
    end,
  },
}
