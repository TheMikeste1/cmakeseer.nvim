local overseer = require("overseer")
local Cmakeseer = require("cmakeseer")

--- @return overseer.TaskDefinition
local function builder()
  return {
    name = "CMake Configure",
    cmd = Cmakeseer.cmake_command(),
    args = Cmakeseer.get_configure_args(),
    components = {
      "cmakeseer.configure_hooks",
      {
        "unique",
        restart_interrupts = false,
      },
      "default",
    },
  }
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Configure",
  desc = "Configure the current CMake projects",
  tags = { overseer.TAG.BUILD },
  builder = builder,
}
