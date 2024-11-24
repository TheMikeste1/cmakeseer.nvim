local Cmakeseer = require("cmakeseer")
local Utils = require("cmakeseer.utils")

--- @return overseer.TaskDefinition
local function builder()
  local args = {
    "-S",
    vim.fn.getcwd(),
    "-B",
    Cmakeseer.get_build_directory(),
  }

  if Cmakeseer.selected_kit == nil then
    -- If a kit isn't selected, we'll just select the first
    local kits = Cmakeseer.get_all_kits()
    if #kits >= 1 then
      Cmakeseer.selected_kit = kits[1]
      if Cmakeseer.selected_kit ~= nil then
        vim.notify_once("No kit selected; selecting " .. Cmakeseer.selected_kit.name, vim.log.levels.INFO)
      end
    end
  end

  if Cmakeseer.selected_kit == nil then
    vim.notify_once("Could not find a kit; not specifying compilers in CMake configuration", vim.log.levels.WARN)
  else
    vim.tbl_extend("error", args, {
      "-DCMAKE_C_COMPILER:FILEPATH=" .. Cmakeseer.selected_kit.compilers.C,
      "-DCMAKE_CXX_COMPILER:FILEPATH=" .. Cmakeseer.selected_kit.compilers.CXX,
    })
  end

  local definitions = Utils.create_definition_strings()
  args = Utils.merge_tables(args, definitions)

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
  condition = {
    callback = function()
      return vim.fn.filereadable(vim.fn.getcwd() .. "/CMakeLists.txt") ~= 0
    end,
  },
}
