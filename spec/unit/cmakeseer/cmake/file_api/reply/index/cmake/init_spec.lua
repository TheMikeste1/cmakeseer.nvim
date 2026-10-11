local CMake = require("cmakeseer.cmake.file_api.reply.index.cmake")

---A valid cmake object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    version = {
      major = 3,
      minor = 20,
      patch = 0,
      suffix = "",
      isDirty = false,
    },
    paths = {
      cmake = "/usr/bin/cmake",
      ctest = "/usr/bin/ctest",
      cpack = "/usr/bin/cpack",
      root = "/usr/share/cmake-3.20",
    },
    generator = {
      multiConfig = true,
      name = "Ninja Multi-Config",
      platform = "x64",
    },
  }, overrides or {})
end

---A valid CMake object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("CMake", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local cmake, err = CMake.try_from_json(value)
        assert.is_nil(cmake)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local cmake, err = CMake.try_from_json(valid_json())
      assert.is_nil(err)
      assert.is_not_nil(cmake)
      local instance = assert(cmake)
      assert.are.equal(3, instance.version.major)
      assert.are.equal("/usr/bin/cmake", instance.paths.cmake)
      assert.are.equal("Ninja Multi-Config", instance.generator.name)
    end)

    it("ignores unknown top-level fields", function()
      local cmake, err = CMake.try_from_json(vim.tbl_extend("force", valid_json(), { futureField = "ignored" }))
      assert.is_nil(err)
      assert.is_not_nil(cmake)
      assert.is_nil(rawget(assert(cmake), "futureField"))
    end)

    it("preserves a generator without a platform", function()
      local generator_json = { multiConfig = false, name = "Unix Makefiles" }
      local cmake, err = CMake.try_from_json(valid_json({ generator = generator_json }))
      assert.is_nil(err)
      assert.is_not_nil(cmake)
      local instance = assert(cmake)
      assert.is_false(instance.generator.multi_config)
      assert.is_nil(instance.generator.platform)
    end)

    it("reports paths before generator", function()
      local cmake, err = CMake.try_from_json(valid_json({ paths = {}, generator = "not a table" }))
      assert.is_nil(cmake)
      assert.are.equal("paths cmake is wrong type: nil", err)
    end)

    it("returns an error when version is missing", function()
      local cmake, err = CMake.try_from_json(json_without("version"))
      assert.is_nil(cmake)
      assert.are.equal("version json is wrong type: nil", err)
    end)

    it("returns an error when version is invalid", function()
      local cmake, err = CMake.try_from_json(valid_json({ version = { major = 3 } }))
      assert.is_nil(cmake)
      assert.are.equal("version minor is wrong type: nil", err)
    end)

    it("returns an error when paths is missing", function()
      local cmake, err = CMake.try_from_json(json_without("paths"))
      assert.is_nil(cmake)
      assert.are.equal("paths json is wrong type: nil", err)
    end)

    it("returns an error when paths is invalid", function()
      local cmake, err = CMake.try_from_json(valid_json({ paths = { cmake = "/usr/bin/cmake" } }))
      assert.is_nil(cmake)
      assert.are.equal("paths ctest is wrong type: nil", err)
    end)

    it("returns an error when generator is missing", function()
      local cmake, err = CMake.try_from_json(json_without("generator"))
      assert.is_nil(cmake)
      assert.are.equal("generator json is wrong type: nil", err)
    end)

    it("returns an error when generator is invalid", function()
      local cmake, err = CMake.try_from_json(valid_json({ generator = { name = "Unix Makefiles" } }))
      assert.is_nil(cmake)
      assert.are.equal("generator multiConfig is wrong type: nil", err)
    end)
  end)
end)
