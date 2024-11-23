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

--- Merges two tables arrays into one, leaving duplicates.
--- @param a table The first table.
--- @param b table The second table
function M.merge_tables(a, b)
  if a == nil then
    return b
  end
  if b == nil then
    return a
  end

  local merged_table = {}
  for _, v in ipairs(a) do
    table.insert(merged_table, v)
  end

  for _, v in ipairs(b) do
    table.insert(merged_table, v)
  end

  return merged_table
end

return M
