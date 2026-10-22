local IndexFile = require("cmakeseer.cmake.file_api.reply.index.file")
local file_api = require("cmakeseer.cmake.file_api")

local M = {}

--- Reads and parses a reply index file.
---@param path string The path to the index file.
---@return cmakeseer.cmake.file_api.reply.index.File? obj, string? err The index if successful. Otherwise an error.
local function read_reply_index(path)
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
end

--- Finds the reply index file with the largest identifier. Identifiers are compared lexicographically with the
--- file prefix excluded, as the file API specification requires.
---@param build_dir string The build directory for the API.
---@param prefix "index"|"error" The file prefix to look for.
---@return string? identifier, string? path The identifier and path of the newest matching file, if there is one.
local function newest_index_of_prefix(build_dir, prefix)
  local reply_dir = file_api.reply_dir(build_dir)
  local paths = vim.fn.glob(vim.fs.joinpath(reply_dir, ("%s-*.json"):format(prefix)), true, true)

  local newest_identifier, newest_path = nil, nil
  for _, path in ipairs(paths) do
    local identifier = vim.fs.basename(path):sub(#prefix + 2, -#".json" - 1)
    if newest_identifier == nil or identifier > newest_identifier then
      newest_identifier, newest_path = identifier, path
    end
  end

  return newest_identifier, newest_path
end

--- Finds the index of the most recent configure, successful or not. A failed configure yields an error index, whose
--- `succeeded` field is false and which reports errors for every requested object kind but `configureLog`. A successful
--- index has `succeeded` true but can still have error replies, so an individual error reply alone proves nothing.
---@param build_dir string The build directory for the API.
---@return cmakeseer.cmake.file_api.reply.index.File? index, string? err The index if there is one and it was successfully parsed. An error if it wasn't successfully parsed, and neither if an index doesn't exist.
function M.find_latest_reply_index(build_dir)
  local index_identifier, index_path = newest_index_of_prefix(build_dir, "index")
  local error_identifier, error_path = newest_index_of_prefix(build_dir, "error")

  local path = index_path
  if error_identifier ~= nil and (index_identifier == nil or error_identifier > index_identifier) then
    path = error_path
  end
  if path == nil then
    return nil, "Could not find index"
  end

  return read_reply_index(path)
end

--- Finds the index of the most recent successful configure, ignoring any more recent failure.
---@param build_dir string The build directory for the API.
---@return cmakeseer.cmake.file_api.reply.index.File? index, string? err The index if there is one and it was successfully parsed. An error if it wasn't successfully parsed, and neither if an index doesn't exist.
function M.find_last_successful_reply_index(build_dir)
  local _, path = newest_index_of_prefix(build_dir, "index")
  if path == nil then
    return nil
  end

  return read_reply_index(path)
end

--- Gets the reply for a client stateless query.
---@param build_dir string The build directory for the API.
---@param client string The name or ID of the client.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer The desired major version.
---@param index_time? "latest"|"last_successful" Whether to try getting the latest, even if it's an error, or the last successful index. Defaults to latest.
---@return cmakeseer.cmake.file_api.Reply? reply, string? err The reply, if the file has it. Otherwise an error.
function M.get_client_stateless_reply(build_dir, client, kind, major_version, index_time)
  index_time = index_time or "latest"

  local err
  local index
  if index_time == "latest" then
    index, err = M.find_latest_reply_index(build_dir)
  elseif index_time == "last_successful" then
    index, err = M.find_last_successful_reply_index(build_dir)
  else
    err = "Unknown index_time: " .. vim.inspect(index_time)
  end

  if index == nil then
    return nil, err or "Unknown error"
  end

  if not index.succeeded then
    return nil, "Failed to configure"
  end

  local reply = index:get_client_stateless_reply(client, kind, major_version)
  if reply == nil then
    return nil, "Could not find stateless reply for " .. client
  end
  return reply
end

return M
