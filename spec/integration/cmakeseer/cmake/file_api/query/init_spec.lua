local Stateful = require("cmakeseer.cmake.file_api.query.stateful")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local read_file = require("spec.utils").read_file

--- Gets a valid version for an Object Kind.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType
---@return integer version
local function get_valid_object_kind_version(kind)
  local version = 1
  if kind == object_kind.ObjectKindType.Codemodel or kind == object_kind.ObjectKindType.Cache then
    version = 2
  end
  return version
end

--- Gets if the reply file for an object kind exists.
---@param build_dir string
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType
---@return boolean exists
local function object_kind_file_exists(build_dir, kind)
  local expected_path = vim.fs.joinpath(build_dir, ".cmake", "api", "v1", "reply", ("%s-*.json"):format(kind))
  local matches = vim.fn.glob(expected_path)
  return matches ~= ""
end

--- Gets if the reply index file exists.
---@param build_dir string
---@return boolean exists, string path
local function index_file_exists(build_dir)
  local expected_path = vim.fs.joinpath(build_dir, ".cmake", "api", "v1", "reply", "index-*.json")
  local matches = vim.fn.glob(expected_path)
  return matches ~= "", matches
end

--- Checks if an index file contains an error.
---@param index_path string
---@return boolean has_err
local function index_file_has_error(index_path)
  local file_contents = read_file(index_path)
  local maybe_err = file_contents:find('"error"', 1, true)
  return maybe_err ~= nil
end

describe("file_api.query", function()
  local tmp = require("spec.fixtures.tmpdir")()
  local client = "cmakeseer"

  describe("issue_shared_stateless_query", function()
    for key, value in pairs(object_kind.ObjectKindType) do
      it(("query is accepted for %s"):format(key), function()
        local version = get_valid_object_kind_version(value)
        local err = file_api_query.issue_shared_stateless_query(tmp.path, value, version)
        assert.is_nil(err)
        cmake_configure("object_kinds", tmp.path)

        local index_exists, index_path = index_file_exists(tmp.path)
        assert.is_true(index_exists)
        assert.is_false(index_file_has_error(index_path))
        assert.is_true(object_kind_file_exists(tmp.path, value))
      end)
    end
  end)

  describe("issue_client_stateless_query", function()
    for key, value in pairs(object_kind.ObjectKindType) do
      it(("query is accepted for %s"):format(key), function()
        local version = get_valid_object_kind_version(value)
        local err = file_api_query.issue_client_stateless_query(client, tmp.path, value, version)
        assert.is_nil(err)
        cmake_configure("object_kinds", tmp.path)

        local index_exists, index_path = index_file_exists(tmp.path)
        assert.is_true(index_exists)
        assert.is_false(index_file_has_error(index_path))
        assert.is_true(object_kind_file_exists(tmp.path, value))
      end)
    end
  end)

  describe("issue_client_stateful_query", function()
    it("query is accepted", function()
      local query = Stateful.default()
      for _, value in pairs(object_kind.ObjectKindType) do
        query:add_request({
          kind = value,
          version = get_valid_object_kind_version(value),
        })
      end

      local err = file_api_query.issue_client_stateful_query(client, tmp.path, query)
      assert.is_nil(err)
      cmake_configure("object_kinds", tmp.path)

      local index_exists, index_path = index_file_exists(tmp.path)
      assert.is_true(index_exists)
      assert.is_false(index_file_has_error(index_path))

      for _, value in pairs(object_kind.ObjectKindType) do
        assert.is_true(object_kind_file_exists(tmp.path, value))
      end
    end)
  end)
end)
