local Variable = require("cmakeseer.cmake.cache.variable")

local M = {}

--- Processes a single line from the CMake cache file, updating the provided variable table and description history.
--- @param vars table<string, cmakeseer.cmake.cache.Variable> The table to store and update cache variables.
--- @param working_description string[] A mutable array holding the current description pieces accumulated from comment lines. Will be emptied.
--- @param line string The raw string representing the cache variable line to process.
local function process_cache_line(vars, working_description, line)
  local var = M.parse_cache_variable(line)
  if var == nil then
    vim.notify("Invalid cache item: " .. line, vim.log.levels.ERROR)
    return
  end

  local description = table.concat(working_description)
  -- Clear working_description
  for i = #working_description, 1, -1 do
    working_description[i] = nil
  end

  var.description = description
  vars[var.name] = var

  if vim.endswith(var.name, "-ADVANCED") then
    local target_var_name = var.name:sub(1, #var.name - #"-ADVANCED")
    local target_var = vars[target_var_name]
    if target_var ~= nil then
      target_var.advanced = true
    else
      vim.notify(string.format("Cache variable `%s` is marked advanced, but does not exist??", target_var_name), vim.log.levels.WARN)
    end
  end
end

---@param variable_line string The string containing the cache variable.
---@return cmakeseer.cmake.cache.Variable?
function M.parse_cache_variable(variable_line)
  -- Example:
  -- - `CMAKE_OBJDUMP:FILEPATH=/usr/bin/objdump`
  -- - `CMAKE_PROJECT_COMPAT_VERSION:STATIC=`
  local name, remainder = variable_line:match("(.+):(.*)")
  local type, value = remainder:match("(.+)=(.*)")

  if type == "BOOL" and (value ~= "ON" or value ~= "OFF") then
    return nil
  end

  return Variable:new(name, value, "", type)
end

--- Parses the string containing CMake cache variables.
---@param cache_string string The string containing the cache.
---@return table<string, cmakeseer.cmake.cache.Variable>
function M.parse_cache_string(cache_string)
  ---@type table<string, cmakeseer.cmake.cache.Variable>
  local vars = {}
  local lines = vim.iter(vim.gsplit(cache_string, "\n", { plain = true, trimempty = true })):filter(function(line)
    return not vim.startswith(line, "#") and line ~= ""
  end)
  local working_description = {}
  for line in lines do
    ---@cast line string
    if vim.startswith(line, "//") then
      table.insert(working_description, line:sub(3))
    else
      process_cache_line(vars, working_description, line)
    end
  end

  return vars
end

return M
