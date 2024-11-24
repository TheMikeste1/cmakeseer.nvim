local CmakeseerOverseerConfigure = require("overseer.template.cmakeseer.cmake_configure")

--- @return overseer.TaskDefinition
local function builder(params)
  local config = CmakeseerOverseerConfigure.builder(params)
  config.name = "CMake Configure (fresh)"
  table.insert(config.args, 1, "--fresh")
  return config
end

--- @type overseer.TemplateFileDefinition
return vim.tbl_deep_extend("force", CmakeseerOverseerConfigure, {
  name = "CMake Configure (fresh)",
  desc = "Freshly configure the current CMake project, deleting the current cache",
  builder = builder,
})
