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
    local templates = {
      -- TODO: Add cmake_build_target for each target (maybe provide an option)
      -- Also provide one for the currently selected target.
      require("overseer.template.cmakeseer.cmake_build"),
      require("overseer.template.cmakeseer.cmake_build_target"),
      require("overseer.template.cmakeseer.cmake_clean"),
      require("overseer.template.cmakeseer.cmake_clean_rebuild"),
      require("overseer.template.cmakeseer.cmake_configure"),
      require("overseer.template.cmakeseer.cmake_configure_fresh"),
      require("overseer.template.cmakeseer.cmake_install"),
    }

    local target_templates = generate_build_targets()
    templates = Utils.merge_arrays(templates, target_templates)

    cb(templates)
  end,
  condition = {
    callback = function(search)
      return vim.fn.filereadable(vim.fs.joinpath(search.dir, "CMakeLists.txt")) ~= 0 or Cmakeseer.is_cmake_project()
    end,
  },
  cache_key = function(opts)
    return vim.fs.joinpath(Cmakeseer.get_build_directory(), "CMakeCache.txt")
  end,
}
