local Cmakeseer = require("cmakeseer")

local function builder()
  ---@type overseer.TaskDefinition
  return {
    name = "CMake Clean",
    cmd = "cmake",
    args = {
      "--build",
      Cmakeseer.get_build_directory(),
      "--target",
      "clean",
    },
  }
end

---@type overseer.TemplateFileDefinition
return {
  name = "CMake Clean",
  desc = "Cleans the CMake build directory",
  builder = builder,
  condition = {
    callback = Cmakeseer.project_is_configured,
  },
}
