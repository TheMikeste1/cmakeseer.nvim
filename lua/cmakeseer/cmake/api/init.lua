local ObjectKind = require("cmakeseer.cmake.api.model.object_kind")
local Utils = require("cmakeseer.utils")

local _M = {}

--- Coverts a string from camel to snakecase.
---@param str string The string to convert.
---@return string str The converted string.
function _M.camel_to_snakecase(str)
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
function _M.convert_array_object_fields_to_snakecase(array)
  for i, value in ipairs(array) do
    if type(value) == "table" then
      if Utils.is_array(value) then
        value = _M.convert_array_object_fields_to_snakecase(value)
      else
        value = _M.convert_fields_to_snakecase(value)
      end

      array[i] = value
    end
  end
  return array
end

--- Converts the fields of a table to snakecase.
---@param obj table<string, any> The table containing fields to convert.
function _M.convert_fields_to_snakecase(obj)
  for name, value in pairs(obj) do
    if type(value) == "table" then
      if Utils.is_array(value) then
        value = _M.convert_array_object_fields_to_snakecase(value)
      else
        value = _M.convert_fields_to_snakecase(value)
      end
    end

    local snakecase = _M.camel_to_snakecase(name)
    obj[name] = nil
    obj[snakecase] = value
  end
  return obj
end

local M = {}

--- Reads a file and returns the associated ObjectKind, if it contains one.
--- @param filename string The file containing the ObjectKind.
--- @return ObjectKind? object_kind The object kind in the file, nil if the file didn't contain one.
function M.read_object_kind_file(filename)
  local file_contents = vim.fn.readfile(filename)
  if #file_contents == 0 then
    return nil
  end

  local maybe_object_kind = vim.fn.json_decode(file_contents)
  maybe_object_kind = _M.convert_fields_to_snakecase(maybe_object_kind)
  if not ObjectKind.is_valid(maybe_object_kind) then
    return nil
  end

  return maybe_object_kind
end

return M
