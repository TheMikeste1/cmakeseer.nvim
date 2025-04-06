--- @module "overseer.template"

local CmakeUtils = require("cmakeseer.cmake.utils")
local Cmakeseer = require("cmakeseer")
local CmakeseerCallbacks = require("cmakeseer.callbacks")
local Settings = require("cmakeseer.settings")
local Utils = require("cmakeseer.utils")

--- @return overseer.TaskDefinition
local function builder()
  local args = {
    "-S",
    vim.fn.getcwd(),
    "-B",
    Cmakeseer.get_build_directory(),
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
  }

  local maybe_selected_kit = Cmakeseer.selected_kit()
  if maybe_selected_kit == nil then
    vim.notify("No kit selected; not specifying compilers in CMake configuration", vim.log.levels.WARN)
  else
    table.insert(args, "-DCMAKE_C_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.C)
    table.insert(args, "-DCMAKE_CXX_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.CXX)
  end

  local configure_settings = Settings.get_settings().configureSettings
  local definitions = CmakeUtils.create_definition_strings(configure_settings)
  args = Utils.merge_arrays(args, definitions)

  local additional_args = Settings.get_settings().configureArgs
  args = Utils.merge_arrays(args, additional_args)

  CmakeseerCallbacks.onPreConfigure()

  return {
    name = "CMake Configure",
    cmd = "cmake",
    args = args,
    components = {
      {
        "unique",
        restart_interrupts = false,
      },
      "default",
    },
  }
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Configure",
  desc = "Configure the current CMake projects",
  builder = builder,
}
