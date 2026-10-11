--- A reply to a client query.
---@class cmakeseer.cmake.file_api.reply.Client
---@field kind "malformed" The type delimiter for for reply type.
---@field json table<string, any> The malformed JSON.

--- A malformed reply that could not be parsed.
---@class cmakeseer.cmake.file_api.reply.Malformed
---@field kind "malformed" The type delimiter for for reply type.
---@field json table<string, any> The malformed JSON.

--- A reply to a shared query.
---@class cmakeseer.cmake.file_api.reply.Shared
---@field kind "shared_reply" The type delimiter for for reply type.
---@field reply cmakeseer.cmake.file_api.reply.FileReference The reply.

--- An error reply to a shared query.
---@class cmakeseer.cmake.file_api.reply.SharedError
---@field kind "shared_error" The type delimiter for for reply type.
---@field error string The error message.

--- A reply to a query.
---@alias cmakeseer.cmake.file_api.Reply
---| cmakeseer.cmake.file_api.reply.Client
---| cmakeseer.cmake.file_api.reply.Malformed
---| cmakeseer.cmake.file_api.reply.Shared
---| cmakeseer.cmake.file_api.reply.SharedError
