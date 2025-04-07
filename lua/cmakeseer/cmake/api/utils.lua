local Utils = require("cmakeseer.utils")

local M = {
  __api_directory = ".cmake/api/v1",
}

---@return string api_directory The subpath to the API directory where queries and responses are made.
function M.api_directory()
  return M.__api_directory
end

--- Coverts a string from camel to snakecase.
---@param str string The string to convert.
---@return string str The converted string.
function M.camel_to_snakecase(str)
  local result = string.lower(str:sub(1, 1))
  for c in str:sub(2, #str):gmatch(".") do
    if string.match(c, "%u") then
      result = result .. "_" .. string.lower(c)
    else
      result = result .. c
    end
  end
  return result
end

--- Converts the fields objects inside an array to snakecase.
---@param array table<integer, any> The array containing objects with fields to convert.
---@return table<integer, any> array The original array with contained object's fields converted.
function M.convert_array_object_fields_to_snakecase(array)
  for i, value in ipairs(array) do
    if type(value) == "table" then
      if Utils.is_array(value) then
        value = M.convert_array_object_fields_to_snakecase(value)
      else
        value = M.convert_fields_to_snakecase(value)
      end

      array[i] = value
    end
  end
  return array
end

--- Converts the fields of a table to snakecase.
---@param obj table<string, any> The table containing fields to convert.
function M.convert_fields_to_snakecase(obj)
  for name, value in pairs(obj) do
    if type(value) == "table" then
      if Utils.is_array(value) then
        value = M.convert_array_object_fields_to_snakecase(value)
      else
        value = M.convert_fields_to_snakecase(value)
      end
    end

    local snakecase = M.camel_to_snakecase(name)
    obj[name] = nil
    obj[snakecase] = value
  end
  return obj
end

return M
