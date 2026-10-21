local Install = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.install")

---A valid destination, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function destination_json(overrides)
  return vim.tbl_extend("force", { path = "bin", backtrace = 0 }, overrides or {})
end

---A valid install JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    prefix = { path = "/usr/local" },
    destinations = { destination_json() },
  }, overrides or {})
end

---The install CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install install
local function valid_install()
  return {
    prefix = "/usr/local",
    destinations = { { path = "bin", backtrace = 0 } },
  }
end

---A valid install JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses an install object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install? obj, string? err
local function try_from_json(overrides)
  return Install.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.Install", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "install" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local install, err = Install.try_from_json(value)
        assert.is_nil(install)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local install, err = Install.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_install(), assert(install))
    end)

    it("returns an error when prefix is missing", function()
      local install, err = Install.try_from_json(json_without("prefix"))
      assert.is_nil(install)
      assert.are.equal("prefix is wrong type: nil", err)
    end)

    it("returns an error when prefix is not a table", function()
      local install, err = try_from_json({ prefix = "/usr" })
      assert.is_nil(install)
      assert.are.equal("prefix is wrong type: string", err)
    end)

    it("returns an error when prefix.path is missing", function()
      local install, err = try_from_json({ prefix = {} })
      assert.is_nil(install)
      assert.are.equal("prefix.path is wrong type: nil", err)
    end)

    it("returns an error when prefix.path is not a string", function()
      local install, err = try_from_json({ prefix = { path = 42 } })
      assert.is_nil(install)
      assert.are.equal("prefix.path is wrong type: number", err)
    end)

    it("returns an error when destinations is missing", function()
      local install, err = Install.try_from_json(json_without("destinations"))
      assert.is_nil(install)
      assert.are.equal("destinations is missing", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "destinations" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when destinations is %s"):format(label), function()
        local install, err = try_from_json({ destinations = value })
        assert.is_nil(install)
        assert.are.equal(("destinations is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when a destination is not a table", function()
      local install, err = try_from_json({ destinations = { "bin" } })
      assert.is_nil(install)
      assert.are.equal("destinations[1] is wrong type: string", err)
    end)

    it("returns an error when the path of a destination is missing", function()
      local install, err = try_from_json({ destinations = { {} } })
      assert.is_nil(install)
      assert.are.equal("destinations[1].path is wrong type: nil", err)
    end)

    it("returns an error when the path of a destination is not a string", function()
      local install, err = try_from_json({ destinations = { { path = 42 } } })
      assert.is_nil(install)
      assert.are.equal("destinations[1].path is wrong type: number", err)
    end)

    it("returns an error when the backtrace of a destination is not a number", function()
      local install, err = try_from_json({ destinations = { { path = "bin", backtrace = "0" } } })
      assert.is_nil(install)
      assert.are.equal("destinations[1].backtrace is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local install, err = Install.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(install), "futureField"))
    end)
  end)
end)
