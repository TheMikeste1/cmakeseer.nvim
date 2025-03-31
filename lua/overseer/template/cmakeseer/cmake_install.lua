local Cmakeseer = require("cmakeseer")

local function builder()
  -- TODO: Add option to use sudo
  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Install",
    cmd = "cmake",
    args = {
      "--install",
      Cmakeseer.get_build_directory(),
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
    callback = Cmakeseer.project_is_configured,
  },
}
