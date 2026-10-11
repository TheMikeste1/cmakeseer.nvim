local Paths = require("cmakeseer.cmake.file_api.reply.index.cmake.paths")

---A valid paths object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    cmake = "/usr/bin/cmake",
    ctest = "/usr/bin/ctest",
    cpack = "/usr/bin/cpack",
    root = "/usr/share/cmake-3.20",
  }, overrides or {})
end

---A valid paths object with a single field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Paths", function()
  describe("new", function()
    it("initializes correctly", function()
      local paths = Paths.new("/bin/cmake", "/bin/ctest", "/bin/cpack", "/share/cmake")
      assert.are.equal("/bin/cmake", paths.cmake)
      assert.are.equal("/bin/ctest", paths.ctest)
      assert.are.equal("/bin/cpack", paths.cpack)
      assert.are.equal("/share/cmake", paths.root)
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
        local paths, err = Paths.try_from_json(value)
        assert.is_nil(paths)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local paths, err = Paths.try_from_json(valid_json())
      assert.is_nil(err)
      assert.is_not_nil(paths)
      assert(paths)
      assert.are.equal("/usr/bin/cmake", paths.cmake)
      assert.are.equal("/usr/bin/ctest", paths.ctest)
      assert.are.equal("/usr/bin/cpack", paths.cpack)
      assert.are.equal("/usr/share/cmake-3.20", paths.root)
    end)

    it("ignores unknown fields", function()
      local paths, err = Paths.try_from_json(vim.tbl_extend("force", valid_json(), { futureField = "ignored" }))
      assert.is_nil(err)
      assert.is_not_nil(paths)
      assert.is_nil(rawget(assert(paths), "futureField"))
    end)

    it("returns an error when cmake is missing", function()
      local paths, err = Paths.try_from_json(json_without("cmake"))
      assert.is_nil(paths)
      assert.are.equal("cmake is wrong type: nil", err)
    end)

    it("returns an error when cmake is not a string", function()
      local paths, err = Paths.try_from_json(valid_json({ cmake = 1 }))
      assert.is_nil(paths)
      assert.are.equal("cmake is wrong type: number", err)
    end)

    it("returns an error when ctest is missing", function()
      local paths, err = Paths.try_from_json(json_without("ctest"))
      assert.is_nil(paths)
      assert.are.equal("ctest is wrong type: nil", err)
    end)

    it("returns an error when ctest is not a string", function()
      local paths, err = Paths.try_from_json(valid_json({ ctest = 1 }))
      assert.is_nil(paths)
      assert.are.equal("ctest is wrong type: number", err)
    end)

    it("returns an error when cpack is missing", function()
      local paths, err = Paths.try_from_json(json_without("cpack"))
      assert.is_nil(paths)
      assert.are.equal("cpack is wrong type: nil", err)
    end)

    it("returns an error when cpack is not a string", function()
      local paths, err = Paths.try_from_json(valid_json({ cpack = 1 }))
      assert.is_nil(paths)
      assert.are.equal("cpack is wrong type: number", err)
    end)

    it("returns an error when root is missing", function()
      local paths, err = Paths.try_from_json(json_without("root"))
      assert.is_nil(paths)
      assert.are.equal("root is wrong type: nil", err)
    end)

    it("returns an error when root is not a string", function()
      local paths, err = Paths.try_from_json(valid_json({ root = 1 }))
      assert.is_nil(paths)
      assert.are.equal("root is wrong type: number", err)
    end)
  end)
end)
