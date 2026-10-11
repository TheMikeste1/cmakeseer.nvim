local Reply = require("cmakeseer.cmake.file_api.reply.types")
local Stateful = require("cmakeseer.cmake.file_api.reply.stateful")

--- A reply to a client query.
---@class cmakeseer.cmake.file_api.reply.Client
---@field stateless? table<string, cmakeseer.cmake.file_api.Reply> Replies to the stateless queries.
---@field stateful_error? string An error message if the stateful query failed to be parsed.
---@field stateful? cmakeseer.cmake.file_api.reply.Stateful The stateful reply to the stateful query.
local Client = {}
Client.__index = Client

--- Creates a new Client instance.
---@param stateless? table<string, cmakeseer.cmake.file_api.Reply> Replies to the stateless queries.
---@param stateful? cmakeseer.cmake.file_api.reply.Stateful The stateful reply to the stateful query.
---@return cmakeseer.cmake.file_api.reply.Client obj The new instance.
function Client.new(stateless, stateful)
  local self = setmetatable({
    ---@diagnostic disable-next-line: param-type-mismatch
    stateless = vim.deepcopy(stateless),
    ---@diagnostic disable-next-line: param-type-mismatch
    stateful = vim.deepcopy(stateful),
  }, Client)
  return self
end

--- Creates a new Client instance.
---@param stateless? table<string, cmakeseer.cmake.file_api.Reply> Replies to the stateless queries.
---@param stateful_error string The error message
---@return cmakeseer.cmake.file_api.reply.Client obj The new instance.
function Client.new_with_err(stateless, stateful_error)
  local self = setmetatable({
    ---@diagnostic disable-next-line: param-type-mismatch
    stateless = vim.deepcopy(stateless),
    stateful_error = stateful_error,
  }, Client)
  return self
end

--- Creates a new Client instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.Client? obj, string? err The new instance if successful. Otherwise an error.
function Client.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local raw_stateful = json["query.json"]
  json = vim.deepcopy(json) -- Avoid mutating the caller
  json["query.json"] = nil

  ---@type table<string, cmakeseer.cmake.file_api.Reply>?
  local stateless
  if next(json) ~= nil then
    stateless = {}
    for key, response in pairs(json) do
      stateless[key] = Reply.from_json(response, index_file_path)
    end
  end

  ---@type cmakeseer.cmake.file_api.reply.Stateful?
  local stateful
  local err
  if raw_stateful ~= nil then
    if type(raw_stateful) ~= "table" then
      return nil, "query.json is wrong type: " .. type(raw_stateful)
    end
    if raw_stateful.error then
      return Client.new_with_err(stateless, raw_stateful.error)
    end

    stateful, err = Stateful.try_from_json(raw_stateful, index_file_path)
    if stateful == nil then
      return nil, "query.json " .. err
    end
  end

  return Client.new(stateless, stateful)
end

return Client
