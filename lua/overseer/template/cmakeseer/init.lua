local Cmakeseer = require("cmakeseer")
local Utils = require("cmakeseer.utils")
local TargetBuilder = require("overseer.template.cmakeseer.target_builder")

local function generate_build_targets()
  local templates = {}
  for _, target in ipairs(Cmakeseer.get_targets()) do
    local template = TargetBuilder.build_template_for(target.name, target.type)
    table.insert(templates, template)
  end
  return templates
end

---@type overseer.TemplateProvider
return {
  name = "CMakeSeer",
  module = "cmakeseer",
  generator = function(search, cb)
    if vim.fn.filereadable(vim.fs.joinpath(search.dir, "CMakeLists.txt")) == 0 and not Cmakeseer.is_cmake_project() then
      return
    end

    local templates = {
      -- TODO: Allow users to select a target and provide a template for that target
      require("overseer.cmakeseer.template.cmake_build"),
      require("overseer.cmakeseer.template.cmake_configure"),
    }

    if Cmakeseer.project_is_configured() then
      vim.list_extend(templates, {
        require("overseer.cmakeseer.template.cmake_build_target"),
        require("overseer.cmakeseer.template.cmake_clean"),
        require("overseer.cmakeseer.template.cmake_clean_rebuild"),
        require("overseer.cmakeseer.template.cmake_configure_fresh"),
        require("overseer.cmakeseer.template.cmake_install"),
      })
      local target_templates = generate_build_targets()
      templates = vim.list_extend(templates, target_templates)
    end

    cb(templates)
  end,
  cache_key = function(_)
    return vim.fs.joinpath(Cmakeseer.get_build_directory(), "CMakeCache.txt")
  end,
}
