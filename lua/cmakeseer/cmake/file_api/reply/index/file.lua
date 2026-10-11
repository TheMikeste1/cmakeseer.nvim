--- A reply in a file.
---@alias cmakeseer.cmake.file_api.FileReply
---| cmakeseer.cmake.file_api.Reply
---| { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }

--- A reply index file, containing information about the build.
---@class cmakeseer.cmake.file_api.reply.index.File
---@field cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@field objects cmakeseer.cmake.file_api.reply.FileReference The list of object kind file references.
---@field replies table<string, cmakeseer.cmake.file_api.FileReply> The query replies.
local File = {}
File.__index = File

--- Creates a new File instance.
---@param cmake cmakeseer.cmake.file_api.reply.index.CMake The CMake information.
---@param objects cmakeseer.cmake.file_api.reply.FileReference The list of object kind file references.
---@param replies table<string, cmakeseer.cmake.file_api.FileReply> The query replies.
---@return cmakeseer.cmake.file_api.reply.index.File obj The new instance.
function File.new(cmake, objects, replies)
  local self = setmetatable({
    cmake = vim.deepcopy(cmake),
    objects = vim.deepcopy(objects),
    replies = replies,
  }, File)
  return self
end

-- TODO(58): try_from_json

return File
