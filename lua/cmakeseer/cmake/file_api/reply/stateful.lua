local Reply = require("cmakeseer.cmake.file_api.reply.types")

--- A reply to a stateful client query.
---@class cmakeseer.cmake.file_api.reply.Stateful
---@field requests? cmakeseer.cmake.file_api.query.ObjectKind[] A copy of the made requests, if it was well-formed.
---@field responses? cmakeseer.cmake.file_api.Reply[] The responses to the query. Will not be present if error ~= nil.
---@field error? string An error, if the requests field in the query was missing or invalid.
---@field client? table Optional values to be copied into the reply from the query, but not used by CMake itself.
local Stateful = {}
Stateful.__index = Stateful

--- Creates a new Stateful instance.
---@param requests? cmakeseer.cmake.file_api.query.ObjectKind[] A copy of the made requests.
---@param responses cmakeseer.cmake.file_api.Reply[] The responses to the query. Will not be present if error ~= nil.
---@param client? table Optional values to be copied into the reply from the query, but not used by CMake itself.
---@return cmakeseer.cmake.file_api.reply.Stateful obj The new instance.
function Stateful.new(requests, responses, client)
  local self = setmetatable({
    ---@diagnostic disable-next-line: param-type-mismatch
    requests = vim.deepcopy(requests),
    responses = vim.deepcopy(responses),
    ---@diagnostic disable-next-line: param-type-mismatch
    client = vim.deepcopy(client),
  }, Stateful)
  return self
end

--- Creates a new Stateful instance.
---@param requests? cmakeseer.cmake.file_api.query.ObjectKind[] A copy of the made requests.
---@param error string An error, if the requests field in the query was missing or invalid.
---@param client? table Optional values to be copied into the reply from the query, but not used by CMake itself.
---@return cmakeseer.cmake.file_api.reply.Stateful obj The new instance.
function Stateful.new_with_error(requests, error, client)
  local self = setmetatable({
    ---@diagnostic disable-next-line: param-type-mismatch
    requests = vim.deepcopy(requests),
    error = error,
    ---@diagnostic disable-next-line: param-type-mismatch
    client = vim.deepcopy(client),
  }, Stateful)
  return self
end

--- Creates a new Stateful instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.Stateful? obj, string? err The new instance if successful. Otherwise an error.
function Stateful.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local client = json["client"]
  -- We're not going to do any validation on client.
  -- CMake doesn't care, so we won't either.

  local requests = json["requests"]
  if requests ~= nil and type(requests) ~= "table" then
    return nil, "requests is wrong type: " .. type(requests)
  end
  -- I really should validate this, but I'm not going to right now. . .
  -- Especially since I don't think most clients will actually use this field

  local raw_responses = json["responses"]
  if type(raw_responses) ~= "table" then
    return nil, "responses is wrong type: " .. type(raw_responses)
  end
  if raw_responses.error ~= nil then
    return Stateful.new_with_error(requests, raw_responses.error, client)
  end

  ---@type cmakeseer.cmake.file_api.Reply[]
  local responses = vim
    .iter(raw_responses)
    :map(function(res_json)
      return Reply.from_json(res_json, index_file_path) ---@diagnostic disable-line: missing-return-value
    end)
    :totable()

  return Stateful.new(requests, responses, client)
end

return Stateful
