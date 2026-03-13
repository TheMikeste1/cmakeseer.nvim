--- TODO: Allow custom variants
---@enum cmakeseer.Variant
local Variant = {
  Debug = "Debug",
  Release = "Release",
  RelWithDebInfo = "RelWithDebInfo",
  MinSizeRel = "MinSizeRel",
  Unspecified = "Unspecified",
}

--- @type cmakeseer.Kit[]
local __discovered_kits = {}
--- @type cmakeseer.Kit? The selected kit. May be `nil` if one has not been selected. May not be in `__discovered_kits` if using one of the default kits from the user's configuration.
local __selected_kit = nil
--- @type cmakeseer.cmake.api.codemodel.Target[]
local __targets = {}
---@type cmakeseer.Variant
local __selected_variant = Variant.Debug
---@type cmakeseer.cmake.api.CTestInfo?
local __ctest_info = nil

local M = {
  Variant = Variant,
}

---@return cmakeseer.Kit[] kits The list of discovered kits.
function M.discovered_kits()
  return vim.deepcopy(__discovered_kits, true)
end

---@param kits cmakeseer.Kit[] The kits to be set.
function M.set_discovered_kits(kits)
  -- TODO: Validate kits
  __discovered_kits = kits
end

---@return cmakeseer.Variant variant The selected variant.
function M.selected_variant()
  return __selected_variant
end

---@param variant cmakeseer.Variant The variant to set.
function M.set_selected_variant(variant)
  __selected_variant = variant
end

---@return cmakeseer.cmake.api.codemodel.Target[] targets The list of CMake targets.
function M.targets()
  return __targets
end
M.get_targets = M.targets

---@param targets  cmakeseer.cmake.api.codemodel.Target[] The new list of CMake targets.
function M.set_targets(targets)
  --- TODO: Validate targets
  __targets = targets
end

---@return cmakeseer.cmake.api.codemodel.Target[] targets The list of CMake targets.
function M.reload_targets()
  if require("cmakeseer").project_is_configured() then
    require("cmakeseer.callbacks").on_post_configure_success()
  end

  return __targets
end

---@return cmakeseer.Kit? selected_kit The currently selected kit, if one exists.
function M.selected_kit()
  if __selected_kit ~= nil then
    return __selected_kit
  end

  local maybe_kit_name = require("cmakeseer.settings").get_settings().kit_name
  if maybe_kit_name then
    local kits = require("cmakeseer").get_all_kits()
    for _, kit in ipairs(kits) do
      if kit.name == maybe_kit_name then
        __selected_kit = kit
        return __selected_kit
      end
    end

    vim.notify_once("Unable to find selected kit: " .. maybe_kit_name, vim.log.levels.ERROR)
  end

  return nil
end

---@param kit cmakeseer.Kit? The kit to which the selected kit should be set. Setting to `nil` resets.
function M.set_selected_kit(kit)
  -- TODO: Validate kit
  __selected_kit = kit
end

---@return cmakeseer.cmake.api.CTestInfo? info The CTest info.
function M.ctest_info()
  return __ctest_info
end
M.get_ctest_info = M.ctest_info

---@param info cmakeseer.cmake.api.CTestInfo? The CTest info.
function M.set_ctest_info(info)
  -- TODO: Validate info
  __ctest_info = info
end

---@return cmakeseer.cmake.api.Test[]? tests The CTest tests.
function M.ctest_tests()
  if __ctest_info ~= nil then
    return vim.deepcopy(__ctest_info.tests, true)
  end
  return nil
end
M.get_ctest_tests = M.ctest_tests

return M
