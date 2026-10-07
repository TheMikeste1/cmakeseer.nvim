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

return M
