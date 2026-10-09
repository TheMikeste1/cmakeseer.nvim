local file_api = require("cmakeseer.cmake.file_api")

-- TODO(55): Implement reply index class
---@class ReplyIndex

-- TODO(58): Implement reply error class
---@class ReplyError

local M = {}

--- A query reply file, either the index or the error.
---@class cmakeseer.cmake.file_api.reply.File
---@field index? ReplyIndex The reply index if the configuration succeeded.
---@field error? { error: ReplyError, get_last_index?: fun(): ReplyIndex } The reply error if the configuration failed, as well as the last index if it exists.

--- Finds the most recent reply file.
---@param build_dir string The build directory for the API.
---@return cmakeseer.cmake.file_api.reply.File? reply_file
function M.find_reply_file(build_dir)
  local reply_dir = file_api.reply_dir(build_dir)
  ---@type string[]
  local reply_files = vim.fn.glob(vim.fs.joinpath(reply_dir, "{index,error}-*.json"), true, true)
  if #reply_files == 0 then
    return nil
  end

  local newest = {
    index = "",
    error = "",
  }
  for _, file in ipairs(reply_files) do
    file = file:sub(#reply_dir + 2) -- +2 because Lua is 1-based, and we need to exclude the '/'
    local reply_type = file:sub(1, #"index")
    local identifier = file:sub(#"index-" + 1, #file - #".json")
    if identifier > newest[reply_type] then
      newest[reply_type] = identifier
    end
  end

  -- TODO(55): Parse the index
  if newest.index > newest.error then
    newest.index = vim.fs.joinpath(reply_dir, "index-" .. newest.index .. ".json")
    return { index = newest.index }
  end

  assert(newest.error ~= "")
  newest.error = vim.fs.joinpath(reply_dir, "error-" .. newest.error .. ".json")
  -- TODO(58): Parse the error
  if newest.index == "" then
    return {
      error = { error = newest.error },
    }
  end

  newest.index = vim.fs.joinpath(reply_dir, "index-" .. newest.index .. ".json")
  return {
    error = {
      error = newest.error,
      get_last_index = function()
        return newest.index
      end,
    },
  }
end

return M
