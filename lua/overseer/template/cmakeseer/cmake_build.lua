local Cmakeseer = require("cmakeseer")

local function builder()
  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Build",
    cmd = "cmake",
    args = {
      "--build",
      Cmakeseer.get_build_directory(),
    },
    components = {
      "cmakeseer.build_hooks",
      {
        "unique",
        restart_interrupts = false,
      },
      "default",
    },
  }

  if not Cmakeseer.project_is_configured() then
    -- Insert just before "default" to minimize shifts
    table.insert(task.components, #task.components - 1, {
      "dependencies",
      task_names = {
        require("overseer.template.cmakeseer.cmake_configure").name,
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
