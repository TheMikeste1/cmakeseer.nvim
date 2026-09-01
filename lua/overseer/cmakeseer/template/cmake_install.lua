---@module "overseer"

local function builder()
  local CMakeSeer = require("cmakeseer")
  -- TODO: Add option to use sudo
  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Install",
    cmd = CMakeSeer.get_config().cmake_command,
    args = {
      "--install",
      CMakeSeer.resolve_build_directory(),
    },
    components = {
      {
        "unique",
        restart_interrupts = false,
      },
      "default",
    },
  }

  return task
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Install",
  desc = "Installs the project",
  builder = builder,
  condition = {
    callback = function()
      return require("cmakeseer").project_is_configured()
    end,
  },
}
