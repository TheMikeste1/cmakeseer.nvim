local CMake = require("cmakeseer.cmake.file_api.reply.index.cmake")
local Client = require("cmakeseer.cmake.file_api.reply.client")
local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")
local Reply = require("cmakeseer.cmake.file_api.reply.types")

--- A reply in a file.
---@alias cmakeseer.cmake.file_api.FileReply
---| cmakeseer.cmake.file_api.Reply
---| { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }

--- A reply index file, containing information about the build.
---@class cmakeseer.cmake.file_api.reply.index.File
---@field cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@field objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@field replies table<string, cmakeseer.cmake.file_api.FileReply> The query replies.
local File = {}
File.__index = File

--- Creates a new File instance.
---@param cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@param objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@param replies table<string, cmakeseer.cmake.file_api.FileReply> The query replies.
---@return cmakeseer.cmake.file_api.reply.index.File obj The new instance.
function File.new(cmake, objects, replies)
  return File.take(vim.deepcopy(cmake), vim.deepcopy(objects), vim.deepcopy(replies))
end

--- Creates a new File instance, owning the objects passed in.
---@param cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@param objects cmakeseer.cmake.file_api.reply.FileReference[] The list of object kind file references.
---@param replies table<string, cmakeseer.cmake.file_api.FileReply> The query replies.
---@return cmakeseer.cmake.file_api.reply.index.File obj The new instance.
function File.take(cmake, objects, replies)
  local self = setmetatable({
    cmake = cmake,
    objects = objects,
    replies = replies,
  }, File)
  return self
end

--- Creates a new File instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.index.File? obj, string? err The new instance if successful. Otherwise an error.
function File.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local cmake, err = CMake.try_from_json(json.cmake)
  if cmake == nil then
    return nil, "cmake " .. err
  end

  local raw_objects = json.objects
  if type(raw_objects) ~= "table" then
    return nil, "objects is wrong type: " .. type(raw_objects)
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

  ---@type table<string, cmakeseer.cmake.file_api.FileReply>
  local replies = {}
  for key, reply_json in pairs(raw_replies) do
    local reply
    if key:sub(1, #"client-") == "client-" then
      reply, err = Client.try_from_json(reply_json, index_file_path)
      if reply ~= nil then
        reply = { kind = "client", client_reply = reply }
      end
    else
      reply = Reply.from_json(reply_json, index_file_path)
    end

    if reply == nil then
      assert(err)
      return nil, ("reply for %s: %s"):format(key, err)
    end

    replies[key] = reply
  end

  return File.take(cmake, objects, replies)
end

return File
