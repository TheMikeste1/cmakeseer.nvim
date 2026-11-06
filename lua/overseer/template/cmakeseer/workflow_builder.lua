---@module "overseer.template"

local M = {}

--- Resolves the binary directories the workflow's configure steps configure into, in step order.
--- A configure step whose preset does not set a `binaryDir` configures into the current working
--- directory (CMake's "regular methods"), which is where the workflow runs.
---@param steps cmakeseer.cmake.preset.WorkflowPreset.Step[] The steps of the workflow.
---@param project_root string The project root to resolve the presets against.
---@return string[] build_dirs The directories the workflow configures into, deduplicated.
local function determine_configure_dirs(steps, project_root)
  local Presets = require("cmakeseer.cmake.preset")
  local cwd = vim.fn.getcwd()

  local build_dirs = {}
  for _, step in ipairs(steps) do
    if step.type == "configure" then
      local build_dir = Presets.try_determine_binary_dir(step.name, project_root, Presets.Types.Configure, { resolve_path = true })
      if build_dir == nil then
        vim.notify(("Configure preset `%s` does not set a `binaryDir`; the workflow will configure into the current working directory"):format(step.name), vim.log.levels.TRACE)
        build_dir = cwd
      end
      table.insert(build_dirs, build_dir)
    end
  end

  return vim.iter(build_dirs):unique():totable()
end

--- Builds a TaskTemplate for the provided workflow preset.
---@param preset string The preset to build.
---@return overseer.TemplateFileDefinition
function M.build_template_for(preset)
  local CMakeSeer = require("cmakeseer")
  local Presets = require("cmakeseer.cmake.preset")

  local entry = Presets.entry_for(preset, CMakeSeer.get_config():get_project_root(), Presets.Types.Workflow)
  assert(entry ~= nil, "Entry must exist for preset")
  ---@cast entry cmakeseer.cmake.preset.WorkflowPreset
  local name = entry.display_name or entry.name
  local desc = entry.description or ("Runs the `%s` workflow"):format(preset)
  return {
    name = ("CMake Workflow %s"):format(name),
    desc = desc,
    --- @return overseer.TaskDefinition
    builder = function()
      local project_root = CMakeSeer.get_config():get_project_root()
      local build_dirs = determine_configure_dirs(entry.steps, project_root)
      local does_build = vim.iter(entry.steps):any(function(step)
        ---@cast step cmakeseer.cmake.preset.WorkflowPreset.Step
        return step.type == "build"
      end)

      local components = {}
      if not vim.tbl_isempty(build_dirs) then
        table.insert(components, {
          "cmakeseer.configure_hooks",
          build_dirs = build_dirs,
        })
      end
      if does_build then
        table.insert(components, "cmakeseer.build_hooks")
      end
      table.insert(components, {
        "unique",
        restart_interrupts = false,
      })
      table.insert(components, "default")

      return {
        name = ("CMake Workflow %s"):format(preset),
        cmd = CMakeSeer.get_config().cmake_command,
        args = { "--workflow", "--preset", preset },
        components = components,
      }
    end,
  }
end

return M
