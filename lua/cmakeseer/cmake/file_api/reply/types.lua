local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")

--- An error reply to a query.
---@class cmakeseer.cmake.file_api.reply.Error
---@field kind "error" The type delimiter for for reply type.
---@field error string The error message.

--- A malformed reply that could not be parsed.
---@class cmakeseer.cmake.file_api.reply.Malformed
---@field kind "malformed" The type delimiter for for reply type.
---@field why string The reason why it was malformed.
---@field json table<string, any> The malformed JSON.

--- A reply to a query.
---@class cmakeseer.cmake.file_api.reply.Valid
---@field kind "valid" The type delimiter for for reply type.
---@field reply cmakeseer.cmake.file_api.reply.FileReference The reply.

--- A reply to a query.
---@alias cmakeseer.cmake.file_api.Reply
---| cmakeseer.cmake.file_api.reply.Error
---| cmakeseer.cmake.file_api.reply.Malformed
---| cmakeseer.cmake.file_api.reply.Valid

local M = {}

--- Creates a new Reply instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.Reply obj The new instance.
function M.from_json(json, index_file_path)
  if type(json) ~= "table" then
    return {
      kind = "malformed",
      why = "Object was not a table. Was a " .. type(json),
      json = json,
    }
  end

  if json.error ~= nil then
    return {
      kind = "error",
      error = json.error,
    }
  end

  local ref, err = FileReference.try_from_json(json, index_file_path)
  if ref == nil then
    return {
      kind = "malformed",
      why = err,
      json = vim.deepcopy(json),
    }
  end
  return {
    kind = "valid",
    reply = ref,
  }
end

return M
