local Reply = require("cmakeseer.cmake.file_api.reply.types")
local Stateful = require("cmakeseer.cmake.file_api.reply.stateful")

--- A reply to a client query.
---@class cmakeseer.cmake.file_api.reply.Client
---@field stateless? table<string, cmakeseer.cmake.file_api.Reply> Replies to the stateless queries.
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

--- Creates a new Client instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.Client? obj, string? err The new instance if successful. Otherwise an error.
function Client.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local raw_stateful = json["query.json"]
  json["query.json"] = nil

  ---@type cmakeseer.cmake.file_api.reply.Stateful?
  local stateful
  local err
  if raw_stateful ~= nil then
    stateful, err = Stateful.try_from_json(raw_stateful, index_file_path)
    if stateful == nil then
      return nil, "query.json " .. err
    end
  end

  ---@type cmakeseer.cmake.file_api.Reply[]
  local stateless = {}
  for key, response in pairs(json) do
    stateless[key] = Reply.from_json(response, index_file_path)
  end

  return Client.new(stateless, stateful)
end

return Client
