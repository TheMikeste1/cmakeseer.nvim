local IndexFile = require("cmakeseer.cmake.file_api.reply.index.file")
local file_api = require("cmakeseer.cmake.file_api")

-- TODO(58): Implement reply error class
---@class ReplyError

local M = {}

--- A query reply file, either the index or the error.
---@class cmakeseer.cmake.file_api.reply.File
---@field index? cmakeseer.cmake.file_api.reply.index.File The reply index if the configuration succeeded.
---@field error? { error: ReplyError, get_last_index?: fun(): cmakeseer.cmake.file_api.reply.index.File?,string? } The reply error if the configuration failed, as well as the last index if it exists.

--- Finds the most recent reply file.
---@param build_dir string The build directory for the API.
---@return cmakeseer.cmake.file_api.reply.File? reply_file, string? error
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

  if newest.index > newest.error then
    local path = vim.fs.joinpath(reply_dir, "index-" .. newest.index .. ".json")
    local f, err = io.open(path, "r")
    if f == nil then
      return nil, "Failed to open index file: " .. err
    end
    local contents = f:read("*a")
    f:close()
    local ok, json = pcall(vim.json.decode, contents, { luanil = { object = true } })
    if not ok then
      return nil, "Failed to decode index file: " .. json
    end

    local index_file
    index_file, err = IndexFile.try_from_json(json, path)
    if index_file == nil then
      return nil, "Failed to parse index file: " .. err
    end
    return { index = index_file }
  end

  assert(newest.error ~= "")
  newest.error = vim.fs.joinpath(reply_dir, "error-" .. newest.error .. ".json")
  -- TODO(58): Parse the error
  if newest.index == "" then
    return {
      error = { error = newest.error },
    }
  end

  return {
    error = {
      error = newest.error,
      get_last_index = function()
        local path = vim.fs.joinpath(reply_dir, "index-" .. newest.index .. ".json")
        local f, err = io.open(path, "r")
        if f == nil then
          return nil, "Failed to open index file: " .. err
        end
        local contents = f:read("*a")
        f:close()
        local ok, json = pcall(vim.json.decode, contents, { luanil = { object = true } })
        if not ok then
          return nil, "Failed to decode index file: " .. json
        end

        local index_file
        index_file, err = IndexFile.try_from_json(json, path)
        if index_file == nil then
          return nil, "Failed to parse index file: " .. err
        end
        return index_file, nil
      end,
    },
  }
end

return M
