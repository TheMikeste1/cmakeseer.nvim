local CMakeSeer = require("cmakeseer")

local M = {}

--- Applies a kit selection to the state. A selection given by name that matches no known kit is reported and ignored.
---@param selection cmakeseer.Kit|string The kit to select, either as a kit or by name.
local function apply_kit_selection(selection)
  if type(selection) == "string" then
    for _, kit in ipairs(CMakeSeer.get_all_kits()) do
      if kit.name == selection then
        CMakeSeer.state.selections.kit = kit
        return
      end
    end
    vim.notify("Unable to find kit: " .. selection, vim.log.levels.ERROR)
    return
  end

  CMakeSeer.state.selections.kit = selection
end

--- Gets the names of all known kits.
---@return string[] names The names of all known kits.
local function kit_names()
  local names = {}
  for _, kit in ipairs(CMakeSeer.get_all_kits()) do
    table.insert(names, kit.name)
  end
  return names
end

--- Select a kit to use
---@param selection cmakeseer.Kit|string? The kit to select, either as a kit or by name. When nil, a picker is opened.
function M.select_kit(selection)
  if selection ~= nil then
    apply_kit_selection(selection)
    return
  end

  local kits = CMakeSeer.get_all_kits()
  vim.ui.select(kits, {
    prompt = "Select kit",
    --- @param item cmakeseer.Kit
    --- @return string
    format_item = function(item)
      local c_compiler = item.compilers.C
      if #c_compiler > 20 then
        c_compiler = vim.fn.pathshorten(c_compiler)
      end

      local cxx_compiler = item.compilers.CXX
      if cxx_compiler == nil then
        cxx_compiler = "<no CXX compiler>"
      end
      if #cxx_compiler > 20 then
        cxx_compiler = vim.fn.pathshorten(cxx_compiler)
      end
      return item.name .. " (" .. c_compiler .. ", " .. cxx_compiler .. ")"
    end,
  }, function(kit)
    if kit == nil then
      return
    end
    apply_kit_selection(kit)
  end)
end

--- Maps the `"<none>"` sentinel to no preset.
---@param preset string The selected preset, or `"<none>"` for none.
---@return string? preset The preset, or nil if none was selected.
local function preset_or_none(preset)
  if preset == "<none>" then
    return nil
  end
  return preset
end

--- Fetches the presets of the given type, plus the `"<none>"` sentinel for no preset.
---@param preset_type cmakeseer.cmake.preset.Type
---@return string[] selections The names of the presets, plus `"<none>"`.
local function preset_selections(preset_type)
  local CMakePreset = require("cmakeseer.cmake.preset")
  local presets = CMakePreset.fetch_presets(require("cmakeseer").get_config():get_project_root(), preset_type)
  table.insert(presets, "<none>")
  return presets
end

--- Select a configure preset to use
---@param preset string? The name of the configure preset to select, or `"<none>"` for none. When nil, a picker is opened.
function M.select_configure_preset(preset)
  local CMakePreset = require("cmakeseer.cmake.preset")

  if preset ~= nil then
    CMakeSeer.state.selections.configure_preset = preset_or_none(preset)
    return
  end

  vim.ui.select(preset_selections(CMakePreset.Types.Configure), {
    prompt = "Select configure preset",
  }, function(selected)
    if selected == nil then
      return
    end
    CMakeSeer.state.selections.configure_preset = preset_or_none(selected)
  end)
end

--- Select a build preset to use
---@param preset string? The name of the build preset to select, or `"<none>"` for none. When nil, a picker is opened.
function M.select_build_preset(preset)
  local CMakePreset = require("cmakeseer.cmake.preset")

  if preset ~= nil then
    CMakeSeer.state.selections.build_preset = preset_or_none(preset)
    return
  end

  vim.ui.select(preset_selections(CMakePreset.Types.Build), {
    prompt = "Select build preset",
  }, function(selected)
    if selected == nil then
      return
    end
    CMakeSeer.state.selections.build_preset = preset_or_none(selected)
  end)
end

--- Gets all available variants: the well-known variants, the additional variants from the configuration,
--- and the configurations reported by the CMake codemodel, in sorted order.
---@return cmakeseer.Variant[] variants All available variants.
local function all_variants()
  local seen = {}
  for _, variant in pairs(CMakeSeer.Variant) do
    seen[variant] = true
  end
  for _, variant in ipairs(CMakeSeer.get_config().additional_variants or {}) do
    seen[variant] = true
  end
  for _, configuration_name in ipairs(CMakeSeer.state.configuration_names() or {}) do
    seen[configuration_name] = true
  end

  local variants = vim.tbl_keys(seen)
  table.sort(variants)
  return variants
end

--- Select a variant to use. When the project is configured, the targets are reloaded to reflect
--- the configuration matching the new variant.
---@param variant cmakeseer.Variant? The variant to select. When nil, a picker is opened.
function M.select_variant(variant)
  if variant ~= nil then
    CMakeSeer.state.selections.variant = variant
    CMakeSeer.state.reload_targets()
    return
  end

  vim.ui.select(all_variants(), {
    prompt = "Select variant",
  }, function(selected)
    if selected == nil then
      return
    end
    CMakeSeer.state.selections.variant = selected
    CMakeSeer.state.reload_targets()
  end)
end

--- Gets the possible selections for a select command, e.g. for command line completion.
---@param command string The name of a select command, e.g. `"select_kit"`.
---@return string[] selections The possible selections, empty if the command is unknown.
function M.selections_for(command)
  local CMakePreset = require("cmakeseer.cmake.preset")

  if command == "select_kit" then
    return kit_names()
  elseif command == "select_configure_preset" then
    return preset_selections(CMakePreset.Types.Configure)
  elseif command == "select_build_preset" then
    return preset_selections(CMakePreset.Types.Build)
  elseif command == "select_variant" then
    return all_variants()
  end

  return {}
end

return M
