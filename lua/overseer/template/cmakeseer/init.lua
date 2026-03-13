---@module "overseer"

---@private
local current_file = nil
local function generate_build_targets()
  local CMakeSeer = require("cmakeseer")
  local templates = {}
  for _, target in ipairs(CMakeSeer.state.get_targets()) do
    local template = require("overseer.template.cmakeseer.target_builder").build_template_for(target.name, target.type)
    table.insert(templates, template)
  end
  return templates
end

local function get_configured_targets()
  local templates = {
    require("overseer.cmakeseer.template.cmake_build_target"),
    require("overseer.cmakeseer.template.cmake_clean"),
    require("overseer.cmakeseer.template.cmake_clean_rebuild"),
    require("overseer.cmakeseer.template.cmake_configure_fresh"),
    require("overseer.cmakeseer.template.cmake_install"),
  }

  local new_current_file = vim.fn.expand("%:.")
  if current_file ~= new_current_file then
    current_file = new_current_file
    table.insert(templates, require("overseer.cmakeseer.template.cmake_build_active_file"))
  end

  local target_templates = generate_build_targets()
  templates = vim.list_extend(templates, target_templates)

  return templates
end

---@type overseer.TemplateProvider
return {
  name = "CMakeSeer",
  module = "cmakeseer",
  generator = function(search, cb)
    local CMakeSeer = require("cmakeseer")

    if vim.fn.filereadable(vim.fs.joinpath(search.dir, "CMakeLists.txt")) == 0 and not CMakeSeer.is_cmake_project() then
      return
    end

    local templates = {
      -- TODO: Allow users to select a target and provide a template for that target
      require("overseer.cmakeseer.template.cmake_build"),
      require("overseer.cmakeseer.template.cmake_configure"),
    }

    if CMakeSeer.project_is_configured() then
      vim.list_extend(templates, get_configured_targets())
    end

    templates = vim
      .iter(templates)
      :filter(function(t)
        if t.condition and t.condition.callback then
          return t.condition.callback()
        end
        return true
      end)
      :totable()

    cb(templates)
  end,
  cache_key = function(_)
    local CMakeSeer = require("cmakeseer")
    return vim.fs.joinpath(CMakeSeer.get_build_directory(), "CMakeCache.txt")
  end,
}
