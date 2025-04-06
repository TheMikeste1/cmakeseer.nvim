local CodeModel = require("cmakeseer.cmake.api.model.codemodel")
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

--- Generates a query object for the given ObjectKind.
---@param kind Kind The object kind for which the query should be generated.
---@return table<string, any>? query The query object for the ObjectKind.
function _M.generate_query_object(kind)
  if kind == ObjectKind.Kind.codemodel then
    return {
      kind = ObjectKind.Kind.codemodel,
      version = {
        major = 2,
      },
    }
  else
    vim.notify("TODO: Implement query for " .. kind)
  end

  return nil
end

local M = {
  --- @enum IssueQueryError The possible types of errors that could be produced when issuing a query.
  IssueQueryError = {
    failed_to_make_directory = 0,
    failed_to_make_query_file = 1,
  },
  __api_directory = ".cmake/api/v1",
}

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

--- Issue a query to the CMake file API.
---@param kinds Kind[]|Kind The Kinds (or Kind) for the query.
---@param build_directory string The directory in which the CMake project will be configured.
---@return IssueQueryError? maybe_error An error, if one occurs.
function M.issue_query(kinds, build_directory)
  if string.sub(build_directory, #build_directory) ~= "/" then
    build_directory = build_directory .. "/"
  end

  local client_dir = build_directory .. M.__api_directory .. "/query/client-cmakeseer"
  local success = vim.fn.mkdir(client_dir, "p") == 1
  if not success then
    return M.IssueQueryError.failed_to_make_directory
  end

  local query = {
    requests = {},
  }

  if type(kinds) == "string" then
    local request = _M.generate_query_object(kinds --[[@as Kind]])
    if request == nil then
      vim.notify("Query not implemented for " .. kinds .. ". Skipping.", vim.log.levels.WARN)
    else
      table.insert(query.requests, request)
    end
  else
    for _, kind in
      ipairs(kinds --[[@as Kind[] ]])
    do
      local request = _M.generate_query_object(kind)
      if request == nil then
        vim.notify("Query not implemented for " .. kind .. ". Skipping.", vim.log.levels.WARN)
      else
        table.insert(query.requests, request)
      end
    end
  end

  local json = vim.fn.json_encode(query)
  success = vim.fn.writefile({ json }, client_dir .. "/query.json") == 0
  if not success then
    return M.IssueQueryError.failed_to_make_query_file
  end
end

return M
