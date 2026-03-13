---@module "overseer"

-- TODO: Add tags to all templates

local function builder()
  local CMakeSeer = require("cmakeseer")

  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Build",
    cmd = CMakeSeer.cmake_command(),
    args = CMakeSeer.get_build_args(),
    components = {
      "cmakeseer.configure_hooks",
      "cmakeseer.build_hooks",
      {
        "unique",
        restart_interrupts = false,
      },
      "default",
    },
  }

  if not CMakeSeer.project_is_configured() then
    -- Insert just before "default" to minimize shifts
    table.insert(task.components, #task.components - 1, {
      "dependencies",
      task_names = {
        require("overseer.cmakeseer.template.cmake_configure").name,
      },
    })
  end

  return task
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Build",
  desc = "Builds all targets in the current CMake project, configuring the project if it isn't already",
  builder = builder,
}
