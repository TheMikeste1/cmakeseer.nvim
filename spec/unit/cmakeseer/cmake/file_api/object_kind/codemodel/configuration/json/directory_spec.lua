local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.directory")

--- The codemodel file the relative jsonFile values of the directories are resolved against.
local CODEMODEL_FILE = vim.fs.joinpath("/tmp/build/.cmake/api/v1/reply", "codemodel-v2-0123456789abcdef.json")

---A valid directory object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    source = "math",
    build = "math",
    parentIndex = 0,
    childIndexes = { 1, 2 },
    projectIndex = 0,
    targetIndexes = { 3, 4 },
    abstractTargetIndexes = { 2 },
    minimumCMakeVersion = { string = "3.28" },
    hasInstallRule = true,
    jsonFile = "directory-math-32bbbeb832184f9886d3.json",
  }, overrides or {})
end

---The directory CMake writes, as parsed from its json.
---@return table<string, any> json
local function valid_directory()
  return {
    source = "math",
    build = "math",
    parent_index = 0,
    child_indices = { 1, 2 },
    project_index = 0,
    target_indices = { 3, 4 },
    abstract_target_indices = { 2 },
    minimum_cmake_version = "3.28",
    has_install_rule = true,
    json_file = vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "directory-math-32bbbeb832184f9886d3.json"),
  }
end

---A valid directory object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Configuration.Json.Directory", function()
  describe("new", function()
    it("initializes correctly", function()
      local directory = Directory.new("math", "math", 0, { 1 }, 0, { 3 }, { 2 }, "3.28", true, "/tmp/build/directory.json")
      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
      assert.are.equal(0, directory.parent_index)
      assert.are.same({ 1 }, directory.child_indices)
      assert.are.equal(0, directory.project_index)
      assert.are.same({ 3 }, directory.target_indices)
      assert.are.same({ 2 }, directory.abstract_target_indices)
      assert.are.equal("3.28", directory.minimum_cmake_version)
      assert.is_true(directory.has_install_rule)
      assert.are.equal("/tmp/build/directory.json", directory.json_file)
    end)

    it("leaves the members that are not passed absent", function()
      local directory = Directory.new(".", ".", nil, nil, 0, nil, nil, nil, false, "/tmp/build/directory.json")
      assert.is_nil(directory.parent_index)
      assert.is_nil(directory.child_indices)
      assert.is_nil(directory.target_indices)
      assert.is_nil(directory.abstract_target_indices)
      assert.is_nil(directory.minimum_cmake_version)
      assert.is_false(directory.has_install_rule)
    end)

    it("does not share the index lists with the caller", function()
      local child_indices, target_indices, abstract_target_indices = { 1 }, { 3 }, { 2 }

      local directory = Directory.new(".", ".", nil, child_indices, 0, target_indices, abstract_target_indices, nil, false, "/d.json")
      child_indices[1] = 9
      target_indices[1] = 9
      abstract_target_indices[1] = 9

      assert.are.same({ 1 }, directory.child_indices)
      assert.are.same({ 3 }, directory.target_indices)
      assert.are.same({ 2 }, directory.abstract_target_indices)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local directory = Directory.take("math", "math", 0, { 1 }, 0, { 3 }, { 2 }, "3.28", true, "/tmp/build/directory.json")
      assert.are.equal("math", directory.source)
      assert.are.equal(0, directory.parent_index)
      assert.are.same({ 1 }, directory.child_indices)
      assert.are.equal("3.28", directory.minimum_cmake_version)
      assert.is_true(directory.has_install_rule)
      assert.are.equal("/tmp/build/directory.json", directory.json_file)
    end)

    -- `take` exists so that a caller that just built the index lists does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local child_indices = { 1 }

      local directory = Directory.take(".", ".", nil, child_indices, 0, nil, nil, nil, false, "/d.json")
      child_indices[1] = 9

      assert.are.equal(9, directory.child_indices[1])
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "math" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local directory, err = Directory.try_from_json(value, CODEMODEL_FILE)
        assert.is_nil(directory)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local directory, err = Directory.try_from_json(valid_json(), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same(valid_directory(), assert(directory))
    end)

    -- CMake reports a directory inside the top-level one by its path relative to that one.
    it("keeps the relative source and build paths of a nested directory", function()
      local directory, err = Directory.try_from_json(valid_json({ source = "math", build = "." }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("math", assert(directory).source)
      assert.are.equal(".", assert(directory).build)
    end)

    it("keeps an absolute source and build path", function()
      local directory, err = Directory.try_from_json(valid_json({ source = "/opt/src/math", build = "/opt/build/math" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("/opt/src/math", assert(directory).source)
      assert.are.equal("/opt/build/math", assert(directory).build)
    end)

    -- CMake leaves out every index list a directory does not use.
    it("leaves the index lists the json omits absent", function()
      local json = json_without("parentIndex")
      json.childIndexes = nil
      json.targetIndexes = nil
      json.abstractTargetIndexes = nil

      local directory, err = Directory.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(assert(directory).parent_index)
      assert.is_nil(assert(directory).child_indices)
      assert.is_nil(assert(directory).target_indices)
      assert.is_nil(assert(directory).abstract_target_indices)
    end)

    it("accepts an empty index list", function()
      local directory, err = Directory.try_from_json(valid_json({ childIndexes = {} }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({}, assert(directory).child_indices)
    end)

    it("keeps an index of 0", function()
      local directory, err = Directory.try_from_json(valid_json({ targetIndexes = { 0 } }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({ 0 }, assert(directory).target_indices)
    end)

    it("keeps a multi digit index", function()
      local directory, err = Directory.try_from_json(valid_json({ targetIndexes = { 10, 11 } }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({ 10, 11 }, assert(directory).target_indices)
    end)

    it("preserves the order of an index list", function()
      local directory, err = Directory.try_from_json(valid_json({ childIndexes = { 2, 1 } }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({ 2, 1 }, assert(directory).child_indices)
    end)

    it("keeps the version string of the minimumCMakeVersion object", function()
      local directory, err = Directory.try_from_json(valid_json({ minimumCMakeVersion = { string = "3.28.1-rc1" } }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("3.28.1-rc1", assert(directory).minimum_cmake_version)
    end)

    it("leaves the minimumCMakeVersion absent when the json omits it", function()
      local directory, err = Directory.try_from_json(json_without("minimumCMakeVersion"), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(assert(directory).minimum_cmake_version)
    end)

    -- CMake only writes hasInstallRule when it is true.
    it("defaults hasInstallRule to false when the json omits it", function()
      local directory, err = Directory.try_from_json(json_without("hasInstallRule"), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_false(assert(directory).has_install_rule)
    end)

    it("keeps hasInstallRule false when the json writes it as false", function()
      local directory, err = Directory.try_from_json(valid_json({ hasInstallRule = false }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_false(assert(directory).has_install_rule)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local directory, err = Directory.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(directory), "futureField"))
    end)

    it("returns an error when source is missing", function()
      local directory, err = Directory.try_from_json(json_without("source"), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("source is wrong type: nil", err)
    end)

    it("returns an error when source is not a string", function()
      local directory, err = Directory.try_from_json(valid_json({ source = 42 }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("source is wrong type: number", err)
    end)

    it("returns an error when build is missing", function()
      local directory, err = Directory.try_from_json(json_without("build"), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("build is wrong type: nil", err)
    end)

    it("returns an error when build is not a string", function()
      local directory, err = Directory.try_from_json(valid_json({ build = 42 }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("build is wrong type: number", err)
    end)

    it("validates the source before the build", function()
      local json = valid_json()
      json.source = nil
      json.build = nil

      local directory, err = Directory.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("source is wrong type: nil", err)
    end)

    for _, entry in ipairs({ { "0", "string" }, { true, "boolean" }, { vim.NIL, "userdata" } }) do
      local value, label = entry[1], entry[2]
      it(("returns an error when parentIndex is a %s"):format(label), function()
        local directory, err = Directory.try_from_json(valid_json({ parentIndex = value }), CODEMODEL_FILE)
        assert.is_nil(directory)
        assert.are.equal(("parentIndex is wrong type: %s"):format(label), err)
      end)
    end

    it("returns an error when parentIndex is negative", function()
      local directory, err = Directory.try_from_json(valid_json({ parentIndex = -1 }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("parentIndex is invalid: -1", err)
    end)

    -- Every index list reports the same failures, so every one of them is exercised with the same values.
    for _, field in ipairs({ "childIndexes", "targetIndexes", "abstractTargetIndexes" }) do
      for _, entry in ipairs({
        { "string", "0", "string" },
        { "dict", { ["0"] = 42 }, "table" },
      }) do
        local label, value, type_name = entry[1], entry[2], entry[3]
        it(("returns an error when %s is a %s"):format(field, label), function()
          local directory, err = Directory.try_from_json(valid_json({ [field] = value }), CODEMODEL_FILE)
          assert.is_nil(directory)
          assert.are.equal(("%s is wrong type: %s"):format(field, type_name), err)
        end)
      end

      it(("returns an error when an element of %s is not a number"):format(field), function()
        local directory, err = Directory.try_from_json(valid_json({ [field] = { 0, "0" } }), CODEMODEL_FILE)
        assert.is_nil(directory)
        assert.are.equal(("%s at 2 is wrong type: string"):format(field), err)
      end)

      it(("returns an error when an element of %s is negative"):format(field), function()
        local directory, err = Directory.try_from_json(valid_json({ [field] = { -1 } }), CODEMODEL_FILE)
        assert.is_nil(directory)
        assert.are.equal(("%s at 1 is invalid: -1"):format(field), err)
      end)
    end

    it("reports the position of the invalid element of an index list", function()
      local directory, err = Directory.try_from_json(valid_json({ targetIndexes = { 0, 1, 2, "3" } }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("targetIndexes at 4 is wrong type: string", err)
    end)

    for _, entry in ipairs({ { "0", "string" }, { true, "boolean" }, { vim.NIL, "userdata" } }) do
      local value, label = entry[1], entry[2]
      it(("returns an error when projectIndex is a %s"):format(label), function()
        local directory, err = Directory.try_from_json(valid_json({ projectIndex = value }), CODEMODEL_FILE)
        assert.is_nil(directory)
        assert.are.equal(("projectIndex is wrong type: %s"):format(label), err)
      end)
    end

    it("returns an error when projectIndex is missing", function()
      local directory, err = Directory.try_from_json(json_without("projectIndex"), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("projectIndex is wrong type: nil", err)
    end)

    it("returns an error when projectIndex is negative", function()
      local directory, err = Directory.try_from_json(valid_json({ projectIndex = -1 }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("projectIndex is invalid: -1", err)
    end)

    -- The upper bound depends on the configuration the directory belongs to, so it is checked when it converts.
    it("accepts a project index past the end of the configuration", function()
      local directory, err = Directory.try_from_json(valid_json({ projectIndex = 99 }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(99, assert(directory).project_index)
    end)

    it("returns an error when minimumCMakeVersion is not an object", function()
      local directory, err = Directory.try_from_json(valid_json({ minimumCMakeVersion = "3.28" }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("minimumCMakeVersion is wrong type: string", err)
    end)

    it("returns an error when minimumCMakeVersion.string is missing", function()
      local directory, err = Directory.try_from_json(valid_json({ minimumCMakeVersion = {} }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("minimumCMakeVersion.string is wrong type: nil", err)
    end)

    it("returns an error when minimumCMakeVersion.string is not a string", function()
      local directory, err = Directory.try_from_json(valid_json({ minimumCMakeVersion = { string = 328 } }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("minimumCMakeVersion.string is wrong type: number", err)
    end)

    it("returns an error when hasInstallRule is not a boolean", function()
      local directory, err = Directory.try_from_json(valid_json({ hasInstallRule = "true" }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("hasInstallRule is wrong type: string", err)
    end)

    it("returns an error when jsonFile is missing", function()
      local directory, err = Directory.try_from_json(json_without("jsonFile"), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("jsonFile is wrong type: nil", err)
    end)

    it("returns an error when jsonFile is not a string", function()
      local directory, err = Directory.try_from_json(valid_json({ jsonFile = 42 }), CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("jsonFile is wrong type: number", err)
    end)

    it("resolves a relative jsonFile against the directory of the codemodel file", function()
      local directory, err = Directory.try_from_json(valid_json({ jsonFile = "directory-a-1.json" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(vim.fs.joinpath(vim.fs.dirname(CODEMODEL_FILE), "directory-a-1.json"), assert(directory).json_file)
    end)

    it("leaves an absolute jsonFile where it is", function()
      local json_file = "/opt/cmake/extra/directory-a-1.json"
      local directory, err = Directory.try_from_json(valid_json({ jsonFile = json_file }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal(json_file, assert(directory).json_file)
    end)

    it("validates the directory members in the order CMake documents them", function()
      local json = valid_json()
      json.source = nil
      json.build = nil
      json.parentIndex = "0"
      json.childIndexes = "0"
      json.projectIndex = nil
      json.targetIndexes = "0"
      json.abstractTargetIndexes = "0"
      json.minimumCMakeVersion = "3.28"
      json.hasInstallRule = "true"
      json.jsonFile = nil

      local directory, err = Directory.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(directory)
      assert.are.equal("source is wrong type: nil", err)
    end)
  end)
end)
