local Cmakeseer = require("cmakeseer")
local CmakeseerOverseerBuild = require("overseer.cmakeseer.template.cmake_build")

--- @return overseer.TaskDefinition
local function builder(params)
  params.target = params.target or "all"

  local config = CmakeseerOverseerBuild.builder(params)
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
    local target_choices = { "all" }
    for _, target_ref in ipairs(Cmakeseer.get_targets()) do
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

          for _, target in ipairs(Cmakeseer.get_targets()) do
            if value == target then
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
    callback = Cmakeseer.project_is_configured,
  },
}
