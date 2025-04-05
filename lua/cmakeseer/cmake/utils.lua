local M = {}

--- Creates a list of CMake definitions strings generated from a map of values.
--- @param configure_settings table<string, string|boolean|number> Contains the definition:value pairs to use when creating the strings.
--- @return table<string> definitions The definitions.
function M.create_definition_strings(configure_settings)
  local definitions = {}

  for key, value in pairs(configure_settings) do
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

return M
