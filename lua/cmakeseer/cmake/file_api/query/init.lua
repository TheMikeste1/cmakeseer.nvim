local file_api = require("cmakeseer.cmake.file_api")
local Stateful = require("cmakeseer.cmake.file_api.query.stateful")

local M = {}

--- Issues a shared stateless query, which is query shared among clients for a specific object kind. See also
--- <https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#v1-shared-stateless-query-files>
---@param build_dir string The build directory for the API.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer
---@return string? err Any error if one occurs.
function M.issue_shared_stateless_query(build_dir, kind, major_version)
  local query_dir = file_api.query_dir(build_dir)
  local query_dir_exists, mkdir_error = pcall(vim.fs.mkdir, query_dir, { parents = true })
  if not query_dir_exists then
    ---@cast mkdir_error string
    return mkdir_error
  end

  local query_file = ("%s-v%d"):format(kind, major_version)
  local query_path = vim.fs.joinpath(query_dir, query_file)
  local f, err = io.open(query_path, "w")
  if f ~= nil then
    f:close()
  end
  return err
end

--- Issues a client stateless query, which is query for a specific client for a specific object kind. See also
--- <https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#v1-client-stateless-query-files>
---@param client string The name or ID of the client.
---@param build_dir string The build directory for the API.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind for the query.
---@param major_version integer
---@return string? err Any error if one occurs.
function M.issue_client_stateless_query(client, build_dir, kind, major_version)
  local query_dir = file_api.query_dir(build_dir)
  local client_dir = ("client-%s"):format(client)
  local client_path = vim.fs.joinpath(query_dir, client_dir)
  local query_dir_exists, mkdir_error = pcall(vim.fs.mkdir, client_path, { parents = true })
  if not query_dir_exists then
    ---@cast mkdir_error string
    return mkdir_error
  end

  local query_file = ("%s-v%d"):format(kind, major_version)
  local query_path = vim.fs.joinpath(client_path, query_file)
  local f, err = io.open(query_path, "w")
  if f ~= nil then
    f:close()
  end
  return err
end

--- Issues a client stateless query, which are more-complex queries for a specific client for multiple
--- object kinds and versions. See also <https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#v1-client-stateful-query-files>.
---@see add_client_stateful_query
---@param client string The name or ID of the client.
---@param build_dir string The build directory for the API.
---@param query cmakeseer.cmake.file_api.query.Stateful The query to issue. Will replace any current query.
---@return string? err Any error if one occurs.
function M.issue_client_stateful_query(client, build_dir, query)
  local query_dir = file_api.query_dir(build_dir)
  local client_dir = ("client-%s"):format(client)
  local client_path = vim.fs.joinpath(query_dir, client_dir)
  local query_dir_exists, mkdir_error = pcall(vim.fs.mkdir, client_path, { parents = true })
  if not query_dir_exists then
    ---@cast mkdir_error string
    return mkdir_error
  end

  local query_path = vim.fs.joinpath(client_path, "query.json")
  return query:to_file(query_path)
end

--- Adds a client stateless query, creating it if needed.
--- See also <https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#v1-client-stateful-query-files>.
---@see issue_client_stateful_query
---@param client string The name or ID of the client.
---@param build_dir string The build directory for the API.
---@param query cmakeseer.cmake.file_api.query.ObjectKind The query to add.
---@param opts table<string, any>? Additional options.
---@return string? err Any error if one occurs.
function M.add_client_stateful_query(client, build_dir, query, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, { append = true })
  ---@cast opts table<string, any>

  local query_dir = file_api.query_dir(build_dir)
  local client_dir = ("client-%s"):format(client)
  local client_path = vim.fs.joinpath(query_dir, client_dir)
  local query_dir_exists, mkdir_error = pcall(vim.fs.mkdir, client_path, { parents = true })
  if not query_dir_exists then
    ---@cast mkdir_error string
    return mkdir_error
  end

  local query_path = vim.fs.joinpath(client_path, "query.json")
  ---@type cmakeseer.cmake.file_api.query.Stateful?
  local full_query
  if vim.uv.fs_stat(query_path) == nil then
    full_query = Stateful.default()
  else
    local err
    full_query, err = Stateful.from_file(query_path)
    if full_query == nil then
      return err
    end
  end

  if opts.append then
    table.insert(full_query.requests, query)
  else
    table.insert(full_query.requests, 1, query)
  end

  return full_query:to_file(query_path)
end

return M
