local function builder()
  local CMakeSeer = require("cmakeseer")
  --- @type overseer.TaskDefinition
  local task = {
    name = "CMake Clean",
    cmd = CMakeSeer.cmake_command(),
    args = CMakeSeer.get_build_args(),
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
    callback = function()
      return require("cmakeseer").project_is_configured()
    end,
  },
}
