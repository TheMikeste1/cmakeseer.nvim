local Cache = require("cmakeseer.cmake.file_api.object_kind.cache")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- The path of the cache object file written by the last configure.
---@param build_dir string
---@return string? path
local function cache_object_path(build_dir)
  local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "cache-*.json")
  local matches = vim.fn.glob(pattern, true, true)
  return matches[1]
end

--- Configures the `object_kinds` project with a cache query issued.
---@param build_dir string
local function configure_with_cache_query(build_dir)
  assert.is_nil(file_api_query.issue_shared_stateless_query(build_dir, object_kind.ObjectKindType.Cache, 2))
  cmake_configure("object_kinds", build_dir)
end

--- Whether the entries contain one with the given name.
---@param entries cmakeseer.cmake.file_api.object_kind.Cache.Entry[]
---@param name string
---@return cmakeseer.cmake.file_api.object_kind.Cache.Entry?
local function find_entry(entries, name)
  for _, entry in ipairs(entries) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end

--- Whether the properties contain one with the given name.
---@param properties cmakeseer.cmake.file_api.object_kind.Cache.Property[]
---@param name string
---@return cmakeseer.cmake.file_api.object_kind.Cache.Property?
local function find_property(properties, name)
  for _, property in ipairs(properties) do
    if property.name == name then
      return property
    end
  end
  return nil
end

describe("object_kind.Cache", function()
  local tmp = require("spec.fixtures.tmpdir")()

  describe("try_from_file", function()
    it("parses the cache object CMake writes", function()
      configure_with_cache_query(tmp.path)
      local path = cache_object_path(tmp.path)
      assert.is_not_nil(path)

      local cache, err = Cache.try_from_file(assert(path))
      assert.is_nil(err)
      local instance = assert(cache)
      assert.are.equal(object_kind.ObjectKindType.Cache, instance.kind)
      assert.are.equal(2, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.is_true(#instance.entries > 0)
    end)

    it("records the cache variable the fixture declares", function()
      configure_with_cache_query(tmp.path)
      local path = cache_object_path(tmp.path)
      assert.is_not_nil(path)

      local cache = assert(Cache.try_from_file(assert(path)))
      local entry = assert(find_entry(cache.entries, "MY_CUSTOM_CACHE_VAR"))
      assert.are.equal("HelloWorld", entry.value)
      assert.are.equal("STRING", entry.type)
      assert.are.equal("A test variable", assert(find_property(entry.properties, "HELPSTRING")).value)
    end)

    -- CMake writes the variable's `type` and property names, but the exact set of entries and
    -- properties depends on the detected toolchain, so assert the shape rather than CMake's output.
    it("parses only strings for every entry and property", function()
      configure_with_cache_query(tmp.path)
      local path = cache_object_path(tmp.path)
      assert.is_not_nil(path)

      local cache = assert(Cache.try_from_file(assert(path)))
      local seen = {}
      for _, entry in ipairs(cache.entries) do
        assert.are.equal("string", type(entry.name))
        assert.are.equal("string", type(entry.value))
        assert.are.equal("string", type(entry.type))
        assert.is_nil(seen[entry.name])
        seen[entry.name] = true

        assert.are.equal("table", type(entry.properties))
        for _, property in ipairs(entry.properties) do
          assert.are.equal("string", type(property.name))
          assert.are.equal("string", type(property.value))
        end
      end
    end)
  end)
end)
