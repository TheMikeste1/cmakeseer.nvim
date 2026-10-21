local Launcher = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.launcher")

---A valid launcher JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    command = "/usr/bin/cmake",
    arguments = { "-E", "env" },
    type = "emulator",
  }, overrides or {})
end

---The launcher CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher launcher
local function valid_launcher()
  return {
    command = "/usr/bin/cmake",
    arguments = { "-E", "env" },
    type = "emulator",
  }
end

---A valid launcher JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a launcher object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher? obj, string? err
local function try_from_json(overrides)
  return Launcher.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.Launcher", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "launcher" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local launcher, err = Launcher.try_from_json(value)
        assert.is_nil(launcher)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local launcher, err = Launcher.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_launcher(), assert(launcher))
    end)

    it("returns an error when command is missing", function()
      local launcher, err = Launcher.try_from_json(json_without("command"))
      assert.is_nil(launcher)
      assert.are.equal("command is wrong type: nil", err)
    end)

    it("returns an error when command is not a string", function()
      local launcher, err = try_from_json({ command = 42 })
      assert.is_nil(launcher)
      assert.are.equal("command is wrong type: number", err)
    end)

    it("returns an error when arguments is missing", function()
      local launcher, err = Launcher.try_from_json(json_without("arguments"))
      assert.is_nil(launcher)
      assert.are.equal("arguments is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "arguments" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when arguments is %s"):format(label), function()
        local launcher, err = try_from_json({ arguments = value })
        assert.is_nil(launcher)
        assert.are.equal(("arguments is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when an argument is not a string", function()
      local launcher, err = try_from_json({ arguments = { "-E", 42 } })
      assert.is_nil(launcher)
      assert.are.equal("arguments[2] is wrong type: number", err)
    end)

    it("returns an error when type is missing", function()
      local launcher, err = Launcher.try_from_json(json_without("type"))
      assert.is_nil(launcher)
      assert.are.equal("type is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "emulator", "emulator" },
      { "test", "test" },
    }) do
      local type_str, expected = entry[1], entry[2]
      it(("records the type %s"):format(type_str), function()
        local launcher, err = try_from_json({ type = type_str })
        assert.is_nil(err)
        assert.are.equal(expected, assert(launcher).type)
      end)
    end

    it("returns an error when type is not a value CMake writes", function()
      local launcher, err = try_from_json({ type = "debugger" })
      assert.is_nil(launcher)
      assert.are.equal("type is invalid: debugger", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local launcher, err = Launcher.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(launcher), "futureField"))
    end)
  end)
end)
