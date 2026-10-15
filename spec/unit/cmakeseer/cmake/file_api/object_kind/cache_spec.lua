local Cache = require("cmakeseer.cmake.file_api.object_kind.cache")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local tmpdir = require("spec.fixtures.tmpdir")

---A valid cache object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "cache",
    version = { major = 2, minor = 0 },
    entries = {
      {
        name = "MY_CUSTOM_CACHE_VAR",
        value = "HelloWorld",
        type = "STRING",
        properties = { { name = "HELPSTRING", value = "A test variable" } },
      },
      {
        name = "CMAKE_BUILD_TYPE",
        value = "Debug",
        type = "STRING",
        properties = {
          { name = "ADVANCED", value = "1" },
          { name = "HELPSTRING", value = "Choose the type of build." },
          { name = "STRINGS", value = "Debug;Release;RelWithDebInfo;MinSizeRel" },
        },
      },
    },
  }, overrides or {})
end

---The entries CMake writes, as parsed from their json.
---@return cmakeseer.cmake.file_api.object_kind.Cache.Entry[]
local function valid_entries()
  return {
    {
      name = "MY_CUSTOM_CACHE_VAR",
      value = "HelloWorld",
      type = "STRING",
      properties = { { name = "HELPSTRING", value = "A test variable" } },
    },
    {
      name = "CMAKE_BUILD_TYPE",
      value = "Debug",
      type = "STRING",
      properties = {
        { name = "ADVANCED", value = "1" },
        { name = "HELPSTRING", value = "Choose the type of build." },
        { name = "STRINGS", value = "Debug;Release;RelWithDebInfo;MinSizeRel" },
      },
    },
  }
end

---A valid cache object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

---A valid cache object with a single version field removed.
---@param field string The version field to remove.
---@return table<string, any> json
local function json_without_version_field(field)
  local json = valid_json()
  json.version[field] = nil
  return json
end

describe("Cache", function()
  local tmp = tmpdir()

  describe("new", function()
    it("initializes correctly", function()
      local entries = valid_entries()
      local cache = Cache.new({ major = 2, minor = 0 }, entries)
      assert.are.equal(object_kind.ObjectKindType.Cache, cache.kind)
      assert.are.equal(2, cache.version.major)
      assert.are.equal(0, cache.version.minor)
      assert.are.same(valid_entries(), cache.entries)
    end)

    it("does not share the version or entries with the caller", function()
      local version = { major = 2, minor = 0 }
      local entries = valid_entries()

      local cache = Cache.new(version, entries)
      version.major = 9
      entries[1].value = "GoodbyeWorld"
      entries[1].properties[1].value = "A different help string"

      assert.are.equal(2, cache.version.major)
      assert.are.same(valid_entries(), cache.entries)
    end)

    it("accepts an empty list of entries", function()
      local cache = Cache.new({ major = 2, minor = 0 }, {})
      assert.are.same({}, cache.entries)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local entries = valid_entries()
      local cache = Cache.take({ major = 2, minor = 0 }, entries)
      assert.are.equal(object_kind.ObjectKindType.Cache, cache.kind)
      assert.are.same({ major = 2, minor = 0 }, cache.version)
      assert.are.same(valid_entries(), cache.entries)
    end)

    -- `take` exists so that a caller that just built the entries does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local version = { major = 2, minor = 0 }
      local entries = valid_entries()

      local cache = Cache.take(version, entries)
      version.major = 9
      entries[1].value = "GoodbyeWorld"

      assert.are.equal(9, cache.version.major)
      assert.are.equal("GoodbyeWorld", cache.entries[1].value)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local cache, err = Cache.try_from_json(value)
        assert.is_nil(cache)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local cache, err = Cache.try_from_json(valid_json())
      assert.is_nil(err)
      local instance = assert(cache)
      assert.are.equal(object_kind.ObjectKindType.Cache, instance.kind)
      assert.are.equal(2, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.same(valid_entries(), instance.entries)
    end)

    it("accepts an empty list of entries", function()
      local cache, err = Cache.try_from_json(valid_json({ entries = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(cache).entries)
    end)

    it("preserves the order of the entries", function()
      local json = valid_json()
      json.entries = { json.entries[2], json.entries[1] }

      local cache, err = Cache.try_from_json(json)
      assert.is_nil(err)
      local entries = assert(cache).entries
      assert.are.equal("CMAKE_BUILD_TYPE", entries[1].name)
      assert.are.equal("MY_CUSTOM_CACHE_VAR", entries[2].name)
    end)

    it("preserves the order of an entry's properties", function()
      local cache, err = Cache.try_from_json(valid_json())
      assert.is_nil(err)
      local properties = assert(cache).entries[2].properties
      assert.are.equal("ADVANCED", properties[1].name)
      assert.are.equal("HELPSTRING", properties[2].name)
      assert.are.equal("STRINGS", properties[3].name)
    end)

    it("accepts an empty list of properties", function()
      local cache, err = Cache.try_from_json(valid_json({
        entries = { { name = "A", value = "1", type = "BOOL", properties = {} } },
      }))
      assert.is_nil(err)
      assert.are.same({ { name = "A", value = "1", type = "BOOL", properties = {} } }, assert(cache).entries)
    end)

    it("keeps an empty entry value", function()
      local cache, err = Cache.try_from_json(valid_json({
        entries = { { name = "A", value = "", type = "STRING", properties = {} } },
      }))
      assert.is_nil(err)
      assert.are.equal("", assert(cache).entries[1].value)
    end)

    it("does not share the entries with the json", function()
      local json = valid_json()
      local cache = assert(Cache.try_from_json(json))

      json.entries[1].value = "GoodbyeWorld"
      json.entries[1].properties[1].value = "A different help string"
      table.remove(json.entries, 2)

      assert.are.same(valid_entries(), cache.entries)
    end)

    it("ignores unknown top-level fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local cache, err = Cache.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(cache), "futureField"))
    end)

    it("ignores unknown fields on an entry", function()
      local json = valid_json({
        entries = { { name = "A", value = "1", type = "BOOL", properties = {}, futureField = "ignored" } },
      })
      local cache, err = Cache.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(cache).entries[1], "futureField"))
    end)

    it("returns an error when the kind is missing", function()
      local cache, err = Cache.try_from_json(json_without("kind"))
      assert.is_nil(cache)
      assert.are.equal("Incorrect kind: nil", err)
    end)

    it("returns an error when the kind is a different object kind", function()
      local cache, err = Cache.try_from_json(valid_json({ kind = "codemodel" }))
      assert.is_nil(cache)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)

    it("returns an error when version is missing", function()
      local cache, err = Cache.try_from_json(json_without("version"))
      assert.is_nil(cache)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local cache, err = Cache.try_from_json(valid_json({ version = 1 }))
      assert.is_nil(cache)
      assert.are.equal("version is wrong type: number", err)
    end)

    it("returns an error when version.major is missing", function()
      local cache, err = Cache.try_from_json(json_without_version_field("major"))
      assert.is_nil(cache)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns an error when version.major is not a number", function()
      local cache, err = Cache.try_from_json(valid_json({ version = { major = "2", minor = 0 } }))
      assert.is_nil(cache)
      assert.are.equal("version.major is wrong type: string", err)
    end)

    it("returns an error when version.minor is missing", function()
      local cache, err = Cache.try_from_json(json_without_version_field("minor"))
      assert.is_nil(cache)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("returns an error when version.minor is not a number", function()
      local cache, err = Cache.try_from_json(valid_json({ version = { major = 2, minor = "0" } }))
      assert.is_nil(cache)
      assert.are.equal("version.minor is wrong type: string", err)
    end)

    it("validates the version before the entries", function()
      local cache, err = Cache.try_from_json(valid_json({ version = "1", entries = 42 }))
      assert.is_nil(cache)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("returns an error when entries is missing", function()
      local cache, err = Cache.try_from_json(json_without("entries"))
      assert.is_nil(cache)
      assert.are.equal("entries is wrong type: nil", err)
    end)

    it("returns an error when entries is not a table", function()
      local cache, err = Cache.try_from_json(valid_json({ entries = "MY_VAR:STRING=1" }))
      assert.is_nil(cache)
      assert.are.equal("entries is wrong type: string", err)
    end)

    it("returns an error when entries is a dict instead of a list", function()
      local cache, err = Cache.try_from_json(valid_json({ entries = { MY_VAR = { name = "MY_VAR" } } }))
      assert.is_nil(cache)
      assert.are.equal("entries is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "MY_VAR:STRING=1" },
      { "null", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when an entry is a %s"):format(label), function()
        local cache, err = Cache.try_from_json(valid_json({ entries = { valid_json().entries[1], value } }))
        assert.is_nil(cache)
        assert.are.equal(("entry at 2: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid entry", function()
      local json = valid_json()
      json.entries[3] = 42

      local cache, err = Cache.try_from_json(json)
      assert.is_nil(cache)
      assert.are.equal("entry at 3: json is wrong type: number", err)
    end)

    for _, entry in ipairs({
      { "name", "nil" },
      { "name", "number" },
      { "value", "nil" },
      { "value", "number" },
      { "type", "nil" },
      { "type", "boolean" },
      { "properties", "nil" },
      { "properties", "string" },
    }) do
      local field, label = entry[1], entry[2]
      it(("returns an error when entry.%s is %s"):format(field, label), function()
        local json = valid_json()
        local entry_json = json.entries[1]
        if label == "nil" then
          entry_json[field] = nil
        elseif field == "properties" then
          entry_json[field] = "HELPSTRING=A test variable"
        else
          entry_json[field] = 42
        end

        local cache, err = Cache.try_from_json(json)
        assert.is_nil(cache)
        local reported_label = field == "properties" and label or (label == "nil" and "nil" or "number")
        assert.are.equal(("entry at 1: %s is wrong type: %s"):format(field, reported_label), err)
      end)
    end

    it("returns an error when entry.properties is a dict instead of a list", function()
      local cache, err = Cache.try_from_json(valid_json({
        entries = { { name = "A", value = "1", type = "BOOL", properties = { HELPSTRING = "help" } } },
      }))
      assert.is_nil(cache)
      assert.are.equal("entry at 1: properties is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "HELPSTRING=A test variable" },
      { "null", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a property is a %s"):format(label), function()
        local json = valid_json()
        table.insert(json.entries[1].properties, value)

        local cache, err = Cache.try_from_json(json)
        assert.is_nil(cache)
        assert.are.equal(("entry at 1: property at 2: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid property within its entry", function()
      local json = valid_json()
      json.entries[2].properties[2].value = nil

      local cache, err = Cache.try_from_json(json)
      assert.is_nil(cache)
      assert.are.equal("entry at 2: property at 2: value is wrong type: nil", err)
    end)

    it("reports the entry a property error belongs to", function()
      local json = valid_json()
      json.entries[2].properties[3].name = nil

      local cache, err = Cache.try_from_json(json)
      assert.is_nil(cache)
      assert.are.equal("entry at 2: property at 3: name is wrong type: nil", err)
    end)

    it("validates the entries before their properties", function()
      local json = valid_json()
      json.entries[1].type = nil
      json.entries[1].properties[1].name = nil

      local cache, err = Cache.try_from_json(json)
      assert.is_nil(cache)
      assert.are.equal("entry at 1: type is wrong type: nil", err)
    end)
  end)

  describe("try_from_file", function()
    --- Writes JSON to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "cache-v2-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("creates an instance from a valid file", function()
      local path = write(vim.json.encode(valid_json()))

      local cache, err = Cache.try_from_file(path)
      assert.is_nil(err)
      local instance = assert(cache)
      assert.are.equal(object_kind.ObjectKindType.Cache, instance.kind)
      assert.are.equal(2, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.same(valid_entries(), instance.entries)
    end)

    it("returns the entry error of the file it could not parse", function()
      local json = vim.json.encode(valid_json({ entries = { { name = "A", value = "1", type = "BOOL" } } }))

      local cache, err = Cache.try_from_file(write(json))
      assert.is_nil(cache)
      assert.are.equal("entry at 1: properties is wrong type: nil", err)
    end)

    it("returns an error when the file does not exist", function()
      local cache, err = Cache.try_from_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(cache)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local cache, err = Cache.try_from_file(dir)
      assert.is_nil(cache)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is not JSON", function()
      local cache, err = Cache.try_from_file(write("not json"))
      assert.is_nil(cache)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the JSON does not describe a cache object", function()
      local cache, err = Cache.try_from_file(write(vim.json.encode(valid_json({ kind = "codemodel" }))))
      assert.is_nil(cache)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)
  end)
end)
