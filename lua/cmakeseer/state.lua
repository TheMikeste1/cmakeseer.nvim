--- TODO: Allow custom variants. We should be able to fetch available configurations from the file API.
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
--- @type cmakeseer.cmake.api.codemodel.Target[]
local __targets = {}

---@class cmakeseer.State.Selections
local __selections = {
  --- @type cmakeseer.Kit? The selected kit. Might be `nil` if one has not been selected.
  kit = nil,
  ---@type cmakeseer.Variant
  variant = Variant.Debug,
  ---@type string?
  preset = nil,
}

---@return cmakeseer.Kit? selected_kit The currently selected kit, if one exists.
local function selected_kit()
  if __selections.kit ~= nil then
    return __selections.kit
  end

  local maybe_kit_name = require("cmakeseer.settings").get_settings().kit_name
  if maybe_kit_name then
    local kits = require("cmakeseer").get_all_kits()
    for _, kit in ipairs(kits) do
      if kit.name == maybe_kit_name then
        __selections.kit = kit
        return __selections.kit
      end
    end

    vim.notify_once("Unable to find selected kit: " .. maybe_kit_name, vim.log.levels.ERROR)
  end

  return nil
end

---@type cmakeseer.State.Selections
local selections_proxy = {}
setmetatable(selections_proxy, {
  --- Handles reads
  __index = function(_, key)
    if key == "kit" then
      return selected_kit()
    end

    return __selections[key]
  end,
  --- Handles writes.
  --- Will handle all writes since the proxy doesn't actually have any contents.
  __newindex = function(_, key, value)
    -- TODO: Handle validation
    __selections[key] = value
  end,
})

local M = {
  Variant = Variant,
  selections = selections_proxy,
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

return M
