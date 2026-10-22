local M = {}

---Gets the API directory given a build directory.
---@param build_dir string The build directory for the API.
---@return string api_dir
local function api_dir(build_dir)
  return vim.fs.joinpath(build_dir, ".cmake", "api", "v1")
end

---Gets the query directory given a build directory.
---@param build_dir string The build directory for the query.
---@return string query_dir
function M.query_dir(build_dir)
  return vim.fs.joinpath(api_dir(build_dir), "query")
end

---Gets the reply directory given a build directory.
---@param build_dir string The build directory for the reply.
---@return string reply_dir
function M.reply_dir(build_dir)
  return vim.fs.joinpath(api_dir(build_dir), "reply")
end

--- Builds the ID for a stateless query or reply.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer The desired major version.
---@return string id
function M.build_stateless_id(kind, major_version)
  return ("%s-v%d"):format(kind, major_version)
end

--- Builds the ID for a client query or reply.
---@param client string The name or ID of the client.
---@return string id
function M.build_client_id(client)
  return ("client-%s"):format(client)
end

---@param build_dir string The build directory for the reply.
---@param client string The name or ID of the client.
---@return boolean
function M.client_query_issued(build_dir, client)
  local query_dir = M.query_dir(build_dir)
  local client_id = M.build_client_id(client)
  local client_dir = vim.fs.joinpath(query_dir, client_id)
  local stat = vim.uv.fs_stat(client_dir)
  return stat ~= nil and stat.type == "directory"
end

return M
