local Generator = require("cmakeseer.cmake.file_api.reply.index.cmake.generator")

---A valid generator object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    multiConfig = true,
    name = "Ninja Multi-Config",
    platform = "x64",
  }, overrides or {})
end

---A valid generator object with a single field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Generator", function()
  describe("new", function()
    it("initializes correctly", function()
      local generator = Generator.new(true, "Ninja Multi-Config", "x64")
      assert.is_true(generator.multi_config)
      assert.are.equal("Ninja Multi-Config", generator.name)
      assert.are.equal("x64", generator.platform)
    end)

    it("stores a nil platform", function()
      assert.is_nil(Generator.new(false, "Unix Makefiles").platform)
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
        local generator, err = Generator.try_from_json(value)
        assert.is_nil(generator)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local generator, err = Generator.try_from_json(valid_json())
      assert.is_nil(err)
      assert.is_not_nil(generator)
      assert(generator)
      assert.is_true(generator.multi_config)
      assert.are.equal("Ninja Multi-Config", generator.name)
      assert.are.equal("x64", generator.platform)
      assert.are.equal(Generator, getmetatable(generator).__index)
    end)

    it("allows a missing platform", function()
      local generator, err = Generator.try_from_json(json_without("platform"))
      assert.is_nil(err)
      assert.is_not_nil(generator)
      assert.is_nil(assert(generator).platform)
    end)

    it("ignores unknown fields", function()
      local generator, err = Generator.try_from_json(vim.tbl_extend("force", valid_json(), { futureField = "ignored" }))
      assert.is_nil(err)
      assert.is_not_nil(generator)
      assert.is_nil(rawget(assert(generator), "futureField"))
    end)

    it("returns an error when multiConfig is missing", function()
      local generator, err = Generator.try_from_json(json_without("multiConfig"))
      assert.is_nil(generator)
      assert.are.equal("multiConfig is wrong type: nil", err)
    end)

    it("returns an error when multiConfig is not a boolean", function()
      local generator, err = Generator.try_from_json(valid_json({ multiConfig = "true" }))
      assert.is_nil(generator)
      assert.are.equal("multiConfig is wrong type: string", err)
    end)

    it("returns an error when name is missing", function()
      local generator, err = Generator.try_from_json(json_without("name"))
      assert.is_nil(generator)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local generator, err = Generator.try_from_json(valid_json({ name = 1 }))
      assert.is_nil(generator)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("returns an error when platform is not a string", function()
      local generator, err = Generator.try_from_json(valid_json({ platform = 1 }))
      assert.is_nil(generator)
      assert.are.equal("platform is wrong type: number", err)
    end)
  end)
end)
