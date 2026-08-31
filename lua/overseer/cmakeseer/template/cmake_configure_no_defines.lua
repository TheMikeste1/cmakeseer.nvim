---@module "overseer"

local function get_name()
  local preset = require("cmakeseer").state.selections.configure_preset
  local name = "CMake Configure"
  if preset ~= nil then
    name = ("%s (%s)"):format(name, preset)
  end
  return name
end

--- @return overseer.TaskDefinition
local function builder()
  local CMakeSeer = require("cmakeseer")
  return {
    name = get_name(),
    cmd = CMakeSeer.get_config().cmake_command,
    args = CMakeSeer.get_basic_configure_args(),
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
  name = "CMake Configure [no defines]",
  desc = "Configure the current CMake projects without additional defines",
  tags = { require("overseer").TAG.BUILD },
  builder = builder,
}
