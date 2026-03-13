---@module "overseer"

-- TODO: Add "Configure with Preset" target

--- @return overseer.TaskDefinition
local function builder()
  local CMakeSeer = require("cmakeseer")
  return {
    name = "CMake Configure",
    cmd = CMakeSeer.cmake_command(),
    args = CMakeSeer.get_configure_args(),
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
  tags = { require("overseer").TAG.BUILD },
  builder = builder,
}
