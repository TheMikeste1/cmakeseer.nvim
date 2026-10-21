local file_api = require("cmakeseer.cmake.file_api")
local spec_utils = require("spec.utils")

local cmake_configure = require("spec.fixtures.cmake.projects.configure")

local M = {}

--- The build directories configured so far, keyed by the project and the queries it was configured with.
---@type table<string, string>
local configured = {}

--- The queries CMake would read from a build directory, in a form that identifies the set.
---@param build_dir string
---@return string fingerprint
local function issued_queries(build_dir)
  local query_dir = file_api.query_dir(build_dir)
  local entries = {}
  -- The queries live in the query directory and, for a client, one directory below it.
  for path, kind in vim.fs.dir(query_dir, { depth = 2 }) do
    if kind == "file" then
      table.insert(entries, ("%s\n%s"):format(path, spec_utils.read_file(vim.fs.joinpath(query_dir, path))))
    end
  end
  table.sort(entries)
  return table.concat(entries, "\n")
end

--- Configures a CMake fixture project, once for every distinct set of queries it is asked for.
---
--- Configuring a fixture dominates the runtime of an integration spec, so the tests that need the same
--- queries against the same project share one configure. The queries are the cache key, so two callers
--- that issue the same queries share a build directory whether or not they say so.
---
--- The build directory is shared by every test that asked for it, so tests must only read from it.
---@param project string The fixture project to configure.
---@param issue_queries fun(build_dir: string) Issues the file API queries into the build directory.
---@return string build_dir The build directory CMake wrote its replies into.
function M.of_project(project, issue_queries)
  local build_dir = spec_utils.make_tmp_dir(project)
  issue_queries(build_dir)

  local key = ("%s\n%s"):format(project, issued_queries(build_dir))
  local already_configured = configured[key]
  if already_configured ~= nil then
    spec_utils.delete_dir(build_dir)
    return already_configured
  end

  cmake_configure(project, build_dir)
  configured[key] = build_dir
  return build_dir
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    if vim.env.KEEP_TEST_DIRS then
      return
    end
    for _, build_dir in pairs(configured) do
      spec_utils.delete_dir(build_dir)
    end
  end,
})

return M
