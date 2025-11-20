local Cmakeseer = require("cmakeseer")

local function builder()
  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Clean",
    cmd = Cmakeseer.cmake_command(),
    args = Cmakeseer.get_build_args(),
  }

  table.insert(task.args, "--target")
  table.insert(task.args, "clean")
  return task
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Clean",
  desc = "Cleans the CMake build directory",
  builder = builder,
  condition = {
    callback = Cmakeseer.project_is_configured,
  },
}
