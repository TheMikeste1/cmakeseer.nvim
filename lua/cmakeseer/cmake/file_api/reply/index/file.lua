local CMake = require("cmakeseer.cmake.file_api.reply.index.cmake")
local Client = require("cmakeseer.cmake.file_api.reply.client")
local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")
local Reply = require("cmakeseer.cmake.file_api.reply.types")
local file_api = require("cmakeseer.cmake.file_api")

--- A reply in a file.
---@alias cmakeseer.cmake.file_api.reply.index.FileReply
---| cmakeseer.cmake.file_api.Reply
---| cmakeseer.cmake.file_api.reply.ClientReply

--- A reply index file, containing information about the build.
---@class cmakeseer.cmake.file_api.reply.index.File
---@field succeeded boolean Whether the configure which produced this index succeeded. False only for an error index.
---@field cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@field objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@field replies table<string, cmakeseer.cmake.file_api.reply.index.FileReply> The query replies.
local File = {}
File.__index = File

--- Creates a new File instance.
---@param succeeded boolean Whether the configure which produced this index succeeded.
---@param cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@param objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@param replies table<string, cmakeseer.cmake.file_api.reply.index.FileReply> The query replies.
---@return cmakeseer.cmake.file_api.reply.index.File obj The new instance.
function File.new(succeeded, cmake, objects, replies)
  return File.take(succeeded, vim.deepcopy(cmake), vim.deepcopy(objects), vim.deepcopy(replies))
end

--- Creates a new File instance, owning the objects passed in.
---@param succeeded boolean Whether the configure which produced this index succeeded.
---@param cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@param objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@param replies table<string, cmakeseer.cmake.file_api.reply.index.FileReply> The query replies.
---@return cmakeseer.cmake.file_api.reply.index.File obj The new instance.
function File.take(succeeded, cmake, objects, replies)
  local self = setmetatable({
    succeeded = succeeded,
    cmake = cmake,
    objects = objects,
    replies = replies,
  }, File)
  return self
end

--- Determines whether the configure which produced the index file at a path succeeded, from the file name prefix.
--- CMake writes `index-*.json` when a configure succeeds and `error-*.json` when it fails.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return boolean? succeeded, string? err True for an index file, false for an error file. Otherwise an error.
local function succeeded_from_path(index_file_path)
  local name = vim.fs.basename(index_file_path)
  if name:sub(1, #"index-") == "index-" then
    return true
  end
  if name:sub(1, #"error-") == "error-" then
    return false
  end
  return nil, ("index file name has neither an 'index-' nor an 'error-' prefix: %s"):format(name)
end

--- Creates a new File instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.index.File? obj, string? err The new instance if successful. Otherwise an error.
function File.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local succeeded, err = succeeded_from_path(index_file_path)
  if succeeded == nil then
    return nil, err
  end

  local cmake
  cmake, err = CMake.try_from_json(json.cmake)
  if cmake == nil then
    return nil, "cmake " .. err
  end

  local raw_objects = json.objects
  if type(raw_objects) ~= "table" then
    return nil, "objects is wrong type: " .. type(raw_objects)
  end
  if not vim.islist(raw_objects) then
    return nil, "objects is a dict instead of a list"
  end

  local raw_replies = json.reply
  if type(raw_replies) ~= "table" then
    return nil, "reply is wrong type: " .. type(raw_replies)
  end

  ---@type cmakeseer.cmake.file_api.reply.FileReference[]
  local objects = {}
  for index, object_json in ipairs(raw_objects) do
    local object
    object, err = FileReference.try_from_json(object_json, index_file_path)
    if object == nil then
      return nil, ("object at %d %s"):format(index, err)
    end
    table.insert(objects, object)
  end

  ---@type table<string, cmakeseer.cmake.file_api.reply.index.FileReply>
  local replies = {}
  for key, reply_json in pairs(raw_replies) do
    assert(type(key) == "string")
    local reply
    if key:sub(1, #"client-") == "client-" then
      reply, err = Client.try_from_json(reply_json, index_file_path)
      if reply == nil then
        assert(err)
        return nil, ("reply for %s: %s"):format(key, err)
      else
        reply = { kind = "client", client_reply = reply }
      end
    else
      reply = Reply.from_json(reply_json, index_file_path)
    end

    replies[key] = reply
  end

  return File.take(succeeded, cmake, objects, replies)
end

--- Gets the reply for a shared stateless query.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer The desired major version.
---@return cmakeseer.cmake.file_api.Reply? reply The reply, if the file has it.
function File:get_shared_stateless_reply(kind, major_version)
  local id = file_api.build_stateless_id(kind, major_version)
  local maybe_reply = self.replies[id]
  assert(maybe_reply == nil or maybe_reply.kind ~= "client")
  return maybe_reply
end

--- Gets the replies for a client's queries.
---@param client string The name or ID of the client.
---@return cmakeseer.cmake.file_api.reply.Client? reply The reply, if the file has it.
function File:get_client_replies(client)
  local client_id = file_api.build_client_id(client)
  local reply = self.replies[client_id]
  if reply == nil then
    return nil
  end
  assert(reply.kind == "client")
  local client_reply = reply.client_reply
  return client_reply
end

--- Gets the reply for a client stateless query.
---@param client string The name or ID of the client.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer The desired major version.
---@return cmakeseer.cmake.file_api.Reply? reply The reply, if the file has it.
function File:get_client_stateless_reply(client, kind, major_version)
  local client_reply = self:get_client_replies(client)
  if client_reply == nil then
    return nil
  end

  return client_reply:get_stateless_reply(kind, major_version)
end

--- Gets the reply for a client stateful query.
---@param client string The name or ID of the client.
---@return cmakeseer.cmake.file_api.reply.Stateful? stateful The stateful, if the file has it.
function File:get_client_stateful(client)
  local client_reply = self:get_client_replies(client)
  if client_reply == nil then
    return nil
  end

  return client_reply.stateful
end

--- Gets the response to a specific stateful query.
---@param client string The name or ID of the client.
---@param kind cmakeseer.cmake.file_api.query.ObjectKind The kind for the response to get.
---@return cmakeseer.cmake.file_api.Reply? reply The reply, if the file has it.
function File:get_client_stateful_response(client, kind)
  local stateful = self:get_client_stateful(client)
  if stateful == nil then
    return nil
  end

  return stateful:get_response(kind)
end

return File
