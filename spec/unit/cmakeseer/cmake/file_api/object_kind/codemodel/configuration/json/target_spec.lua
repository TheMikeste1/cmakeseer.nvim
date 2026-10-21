local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.target")

--- The codemodel file the relative jsonFile values of the targets are resolved against.
local CODEMODEL_FILE = vim.fs.joinpath("/tmp/build/.cmake/api/v1/reply", "codemodel-v2-0123456789abcdef.json")

---A valid target object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    name = "cmakeseer_example",
    id = "cmakeseer_example::@6890427a1f51a3e7e1df",
    directoryIndex = 1,
    projectIndex = 0,
    jsonFile = "target-cmakeseer_example-1fbd134ad5da528f3158.json",
  }, overrides or {})
end

---The target CMake writes, as parsed from its json.
---@return table<string, any> json
local function valid_target()
  return {
    name = "cmakeseer_example",
    id = "cmakeseer_example::@6890427a1f51a3e7e1df",
    directory_index = 1,
    project_index = 0,
    json_file = vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "target-cmakeseer_example-1fbd134ad5da528f3158.json"),
  }
end

---A valid target object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Configuration.Json.Target", function()
  -- A json target holds only strings and numbers, so `new` has nothing to copy and builds what `take` builds.
  describe("new and take", function()
    it("initialize correctly", function()
      local expected = {
        name = "cmakeseer_example",
        id = "id",
        directory_index = 1,
        project_index = 0,
        json_file = "/tmp/build/target.json",
      }

      assert.are.same(expected, Target.new("cmakeseer_example", "id", 1, 0, "/tmp/build/target.json"))
      assert.are.same(expected, Target.take("cmakeseer_example", "id", 1, 0, "/tmp/build/target.json"))
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "target-cmakeseer_example.json" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local target, err = Target.try_from_json(value, CODEMODEL_FILE)
        assert.is_nil(target)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local target, err = Target.try_from_json(valid_json(), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same(valid_target(), assert(target))
    end)

    it("keeps the indexes of the first project and the first directory", function()
      local target, err = Target.try_from_json(valid_json({ directoryIndex = 0, projectIndex = 0 }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(0, assert(target).directory_index)
      assert.are.equal(0, assert(target).project_index)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local target, err = Target.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(target), "futureField"))
    end)

    it("returns an error when name is missing", function()
      local target, err = Target.try_from_json(json_without("name"), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local target, err = Target.try_from_json(valid_json({ name = 42 }), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("returns an error when id is missing", function()
      local target, err = Target.try_from_json(json_without("id"), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("id is wrong type: nil", err)
    end)

    it("returns an error when id is not a string", function()
      local target, err = Target.try_from_json(valid_json({ id = 42 }), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("id is wrong type: number", err)
    end)

    for _, field in ipairs({ "directoryIndex", "projectIndex" }) do
      for _, entry in ipairs({ { "0", "string" }, { true, "boolean" }, { vim.NIL, "userdata" } }) do
        local value, label = entry[1], entry[2]
        it(("returns an error when %s is a %s"):format(field, label), function()
          local target, err = Target.try_from_json(valid_json({ [field] = value }), CODEMODEL_FILE)
          assert.is_nil(target)
          assert.are.equal(("%s is wrong type: %s"):format(field, label), err)
        end)
      end

      it(("returns an error when %s is missing"):format(field), function()
        local target, err = Target.try_from_json(json_without(field), CODEMODEL_FILE)
        assert.is_nil(target)
        assert.are.equal(("%s is wrong type: nil"):format(field), err)
      end)

      -- The upper bound depends on the configuration the target belongs to, so it is checked when it converts.
      it(("accepts an index past the end of the configuration"):format(field), function()
        local target, err = Target.try_from_json(valid_json({ [field] = 99 }), CODEMODEL_FILE)
        assert.is_nil(err)
        assert.are.equal(99, assert(target)[field == "directoryIndex" and "directory_index" or "project_index"])
      end)

      it(("returns an error when %s is negative"):format(field), function()
        local target, err = Target.try_from_json(valid_json({ [field] = -1 }), CODEMODEL_FILE)
        assert.is_nil(target)
        assert.are.equal(("%s is invalid: -1"):format(field), err)
      end)
    end

    it("returns an error when jsonFile is missing", function()
      local target, err = Target.try_from_json(json_without("jsonFile"), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("jsonFile is wrong type: nil", err)
    end)

    it("returns an error when jsonFile is not a string", function()
      local target, err = Target.try_from_json(valid_json({ jsonFile = 42 }), CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("jsonFile is wrong type: number", err)
    end)

    -- CMake writes the jsonFile of a target as a file name next to the codemodel that reports it.
    it("resolves a relative jsonFile against the directory of the codemodel file", function()
      local target, err = Target.try_from_json(valid_json({ jsonFile = "target-a-1.json" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "target-a-1.json"), assert(target).json_file)
    end)

    it("resolves a relative jsonFile written with a parent directory", function()
      local target, err = Target.try_from_json(valid_json({ jsonFile = "sub/target-a-1.json" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "sub", "target-a-1.json"), assert(target).json_file)
    end)

    it("normalizes a relative jsonFile", function()
      local target, err = Target.try_from_json(valid_json({ jsonFile = "./target-a-1.json" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "target-a-1.json"), assert(target).json_file)
    end)

    it("leaves an absolute jsonFile where it is", function()
      local json_file = "/opt/cmake/extra/target-a-1.json"
      local target, err = Target.try_from_json(valid_json({ jsonFile = json_file }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(json_file, assert(target).json_file)
    end)

    it("normalizes an absolute jsonFile", function()
      local json_file = "/tmp/./target-a-1.json"
      local target, err = Target.try_from_json(valid_json({ jsonFile = json_file }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("/tmp/target-a-1.json", assert(target).json_file)
    end)

    it("validates the target members in the order CMake documents them", function()
      local json = valid_json()
      json.name = nil
      json.id = nil
      json.directoryIndex = nil
      json.projectIndex = nil
      json.jsonFile = nil

      local target, err = Target.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(target)
      assert.are.equal("name is wrong type: nil", err)
    end)
  end)
end)
