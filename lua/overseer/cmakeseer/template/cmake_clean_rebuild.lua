local Cmakeseer = require("cmakeseer")
local CmakeseerOverseerBuildAll = require("overseer.cmakeseer.template.cmake_build")

--- @return overseer.TaskDefinition
local function builder(params)
  local config = CmakeseerOverseerBuildAll.builder(params)
  config.name = "CMake Rebuild (clean)"
  table.insert(config.args, "--clean-first")
  return config
end

--- @type overseer.TemplateFileDefinition
return vim.tbl_deep_extend("force", CmakeseerOverseerBuildAll, {
  name = "CMake Rebuild (clean)",
  desc = "Cleans and rebuilds all targets in the current CMake project",
  builder = builder,
  condition = {
    callback = Cmakeseer.project_is_configured,
  },
})
