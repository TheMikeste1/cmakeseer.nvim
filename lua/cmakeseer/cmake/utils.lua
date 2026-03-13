local M = {}

--- Creates a list of CMake definitions strings generated from a map of values.
--- @param configure_settings table<string, string|boolean|number> Contains the definition:value pairs to use when creating the strings.
--- @return table<string> definitions The definitions.
function M.create_definition_strings(configure_settings)
  local definitions = {}

  for key, value in pairs(configure_settings) do
    local definition = { "-D", key }
    local value_type = type(value)

    -- CMake types are defined in <https://cmake.org/cmake/help/latest/command/set.html#set-cache-entry>
    local good = true
    if value_type == "boolean" then
      table.insert(definition, ":BOOL")
    elseif value_type == "number" or value_type == "string" then
      table.insert(definition, ":STRING")
    else
      vim.notify("cmake.configureSettings value for `" .. key .. "` is invalid. Skipping definition.", vim.log.levels.ERROR)
      good = false
    end

    if good then
      table.insert(definition, "=")
      local escaped_value = vim.fn.shellescape(tostring(value))
      table.insert(definition, escaped_value)
      local definition_str = table.concat(definition)
      table.insert(definitions, definition_str)
    end
  end

  return definitions
end

--- Gets the CMake version.
--- @return {major: number, minor: number, patch: number}? version The CMake version.
function M.get_cmake_version()
  local cmake_cmd = require("cmakeseer").cmake_command()
  local obj = vim.system({ cmake_cmd, "--version" }, { text = true }):wait()
  if obj.code ~= 0 then
    return nil
  end

  local major, minor, patch = obj.stdout:match("cmake version (%d+)%.(%d+)%.(%d+)")
  if major and minor and patch then
    return {
      major = tonumber(major),
      minor = tonumber(minor),
      patch = tonumber(patch),
    }
  end
  return nil
end

return M
