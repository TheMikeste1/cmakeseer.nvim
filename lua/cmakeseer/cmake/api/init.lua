local ObjectKind = require("cmakeseer.cmake.api.model.object_kind")
local Utils = require("cmakeseer.utils")

---@class ReplyFileReference A successful reply provided in response to a query.
---@field kind Kind The Kind for which the response if provided.
---@field version Version The Version of the ObjectKind.
---@field json_file string The reference to the JSON file that contains more information. Relative to the index file.

---@class ReplyFileError An error provided in response to a query.
---@field error string The error description

---@alias ApiResponse ReplyFileReference|ReplyFileError The possible response types to a query.

local _M = {
  api_directory = ".cmake/api/v1",
}

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

--- Gets the name of the index file for the CMake API, if one exists.
---@param response_dir string The path to the reply directory used by the CMake API.
---@return string? index_file_path The path to the index file, if one exists.
function _M.get_index_file_path(response_dir)
  local index_files = vim.fs.find(function(name)
    return name:match("index-.+%.json$")
  end, {
    -- There is a small possibility that there are two index files at once. If there is, the lexicographically larger one if the current index.
    -- Source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#v1-reply-index-file
    limit = 2,
    type = "file",
    path = response_dir,
  })
  table.sort(index_files)
  return index_files[#index_files]
end

--- Extracts the responses from an index file.
---@param index_file_path string The path to the index file.
---@return ApiResponse[]? maybe_responses An array of API responses, if the index file had them.
function _M.get_responses_from_index_file(index_file_path)
  local lines = vim.fn.readfile(index_file_path)
  if #lines == 0 then
    return nil
  end

  local contents = vim.fn.json_decode(lines)
  local responses = contents.reply["client-cmakeseer"]["query.json"].responses
  assert(Utils.is_array(responses) or #responses == 0)
  return _M.convert_array_object_fields_to_snakecase(responses)
end

---@param build_directory string The directory in which the CMake project was configured.
---@return string query_directory The directory in which API query files should be written for this client.
function _M.get_query_directory(build_directory)
  return vim.fs.joinpath(build_directory, _M.api_directory, "query/client-cmakeseer")
end

---@param build_directory string The directory in which the CMake project was configured.
---@return string reply_directory The directory in which CMake will provide its responses.
function _M.get_reply_directory(build_directory)
  return vim.fs.joinpath(build_directory, _M.api_directory, "reply")
end

local M = {
  --- @enum IssueQueryError The possible types of errors that could be produced when issuing a query.
  IssueQueryError = {
    FailedToMakeDirectory = 0,
    FailedToMakeQueryFile = 1,
  },
  --- @enum ReadResponseError The possible types of errors that could be produced when reading the response to a query.
  ReadResponseError = {
    IndexDoesNotExist = 0,
  },
}

--- Reads and parses an ObjectKind file given its reference.
---@param reference ReplyFileReference The reference to the ObjectKind file.
---@param build_directory string The directory in which the CMake project was configured.
---@return ObjectKind? maybe_object_kind The parsed ObjectKind, if the file contained a valid one.
function M.parse_object_kind_file(reference, build_directory)
  local response_directory = _M.get_reply_directory(build_directory)
  local filename = vim.fs.joinpath(response_directory, reference.json_file)
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
  local client_dir = _M.get_query_directory(build_directory)
  local success = vim.fn.mkdir(client_dir, "p") == 1
  if not success then
    return M.IssueQueryError.FailedToMakeDirectory
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
    return M.IssueQueryError.FailedToMakeQueryFile
  end
end

--- Read the response to a query from the CMake API.
---@param build_directory string The directory in which the CMake project was configured.
---@return ReplyFileReference[] reply_file_references The list of reply file references provided by the API.
function M.read_responses(build_directory)
  local response_dir = _M.get_reply_directory(build_directory)
  local index_file_path = _M.get_index_file_path(response_dir)
  if index_file_path == nil then
    vim.notify("Cannot read CMake API response. Index file did not exist in " .. response_dir, vim.log.levels.ERROR)
    return {}
  end

  local maybe_responses = _M.get_responses_from_index_file(index_file_path)
  if maybe_responses == nil then
    vim.notify("Index file `" .. index_file_path .. "` did not contain any responses", vim.log.levels.WARN)
    return {}
  end

  return maybe_responses
end

return M
