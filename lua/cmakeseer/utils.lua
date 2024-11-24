local Settings = require("cmakeseer.settings")

local M = {}

--- Creates a list of CMake definitions strings generated from the currents settings.``
--- @return table<string> definitions The definitions.
function M.create_definition_strings()
  local definitions = {}

  for key, value in pairs(Settings.get_settings().configureSettings) do
    local definition = "-D" .. key
    local value_type = type(value)

    -- CMake types are defined in <https://cmake.org/cmake/help/latest/command/set.html#set-cache-entry>
    local good = true
    if value_type == "boolean" then
      definition = definition .. ":BOOL"
    elseif value_type == "number" or value_type == "string" then
      definition = definition .. ":STRING"
    else
      vim.notify(
        "cmake.configureSettings value for `" .. key .. "` is invalid. Skipping definition.",
        vim.log.levels.ERROR
      )
      good = false
    end

    if good then
      definition = definition .. "=" .. tostring(value)
      table.insert(definitions, definition)
    end
  end

  return definitions
end

--- Merges two arrays into one, leaving duplicates.
---@generic T
---@param a T[] The first array.
---@param b T[] The second array.
---@return T[] merged_array The merged array.
function M.merge_arrays(a, b)
  if a == nil then
    return b
  end
  if b == nil then
    return a
  end

  local merged_array = {}
  for _, v in ipairs(a) do
    table.insert(merged_array, v)
  end

  for _, v in ipairs(b) do
    table.insert(merged_array, v)
  end

  return merged_array
end

---@generic T
---@param array T[] The array from which to remove duplicates.
---@return T[] array The array without duplicates.
function M.remove_duplicates(array)
  local merged_set = {}
  for _, v in ipairs(array) do
    if not M.exists(merged_set, v) then
      table.insert(merged_set, v)
    end
  end
  return merged_set
end

--- Merges two sets into one.
---@generic T
---@param a T[] The first set.
---@param b T[] The second set.
---@return T[] merged_set The merged set.
function M.merge_sets(a, b)
  local merged_set = {}

  if a ~= nil then
    for _, v in ipairs(a) do
      if not M.exists(merged_set, v) then
        table.insert(merged_set, v)
      end
    end
  end

  if b ~= nil then
    for _, v in ipairs(b) do
      if not M.exists(merged_set, v) then
        table.insert(merged_set, v)
      end
    end
  end

  return merged_set
end

---@generic T
---@param array T[] The array to check.
---@param element T The element to check.
---@return boolean exists If the element exists in the array.
function M.exists(array, element)
  for _, x in ipairs(array) do
    if x == element then
      return true
    end
  end
  return false
end

return M
