---@module "overseer"

---@private
local current_file = nil
local function generate_build_targets()
  local CMakeSeer = require("cmakeseer")
  local TargetBuilder = require("overseer.template.cmakeseer.target_builder")

  local templates = {}
  for _, target in ipairs(CMakeSeer.state.get_targets()) do
    local template = TargetBuilder.build_template_for(target.name, target.type)
    table.insert(templates, template)
  end
  return templates
end

local function generate_workflow_templates()
  local CMakePreset = require("cmakeseer.cmake.preset")
  local WorkflowBuilder = require("overseer.template.cmakeseer.workflow_builder")

  local presets = CMakePreset.fetch_presets(require("cmakeseer").get_config():get_project_root(), CMakePreset.PresetTypes.Workflow)

  local templates = {}
  for _, preset in ipairs(presets) do
    local template = WorkflowBuilder.build_template_for(preset)
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

    if not CMakeSeer.is_cmake_project() and not CMakeSeer.is_cmake_project(search.dir) then
      return "Project is not a CMake project"
    end

    local templates = {
      -- TODO: Allow users to select a target and provide a template for that target
      require("overseer.cmakeseer.template.cmake_build"),
      require("overseer.cmakeseer.template.cmake_configure"),
      require("overseer.cmakeseer.template.cmake_configure_no_defines"),
    }

    vim.list_extend(templates, generate_workflow_templates())

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
    return CMakeSeer.get_project_cache_file()
  end,
}
