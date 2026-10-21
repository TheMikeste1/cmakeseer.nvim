local Codemodel = require("cmakeseer.cmake.file_api.object_kind.codemodel")
local Configuration = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration")
local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.directory")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local tmpdir = require("spec.fixtures.tmpdir")

--- The codemodel file these tests pretend to have parsed.
local CODEMODEL_FILE = vim.fs.joinpath("/tmp/build/.cmake/api/v1/reply", "codemodel-v2-1.json")

--- The directory the relative jsonFile values of the fixture resolve into.
local REPLY_DIR = vim.fs.dirname(CODEMODEL_FILE)

---A valid configuration object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_configuration_json(overrides)
  return vim.tbl_extend("force", {
    name = "Debug",
    projects = { { name = "CodemodelExample", directoryIndexes = { 0 }, targetIndexes = { 0 } } },
    targets = {
      { name = "cmakeseer_example", id = "cmakeseer_example::@1", directoryIndex = 0, projectIndex = 0, jsonFile = "target-1.json" },
    },
    directories = {
      {
        source = ".",
        build = ".",
        projectIndex = 0,
        targetIndexes = { 0 },
        minimumCMakeVersion = { string = "3.28" },
        hasInstallRule = true,
        jsonFile = "directory-.-1.json",
      },
    },
  }, overrides or {})
end

---A valid codemodel object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "codemodel",
    version = { major = 2, minor = 11 },
    paths = { source = "/tmp/source", build = "/tmp/build" },
    configurations = { valid_configuration_json() },
  }, overrides or {})
end

---The codemodel CMake writes, as parsed from its json.
---@param reply_dir? string The directory the relative jsonFile values resolve into. Defaults to the reply directory of CODEMODEL_FILE.
---@return table<string, any> codemodel
local function valid_codemodel(reply_dir)
  reply_dir = reply_dir or REPLY_DIR
  return {
    kind = "codemodel",
    version = { major = 2, minor = 11 },
    source = "/tmp/source",
    build = "/tmp/build",
    configurations = {
      Debug = {
        name = "Debug",
        projects = {
          CodemodelExample = {
            name = "CodemodelExample",
            children = {},
            targets = { "cmakeseer_example" },
            abstract_targets = {},
            directory_indices = { 0 },
          },
        },
        targets = {
          cmakeseer_example = {
            name = "cmakeseer_example",
            id = "cmakeseer_example::@1",
            directory_index = 0,
            project = "CodemodelExample",
            json_file = vim.fs.joinpath(reply_dir, "target-1.json"),
          },
        },
        abstract_targets = {},
        directories = {
          {
            source = ".",
            build = ".",
            minimum_cmake_version = Directory.MinimumCMakeVersion.new(3, 28),
            has_install_rule = true,
            project = "CodemodelExample",
            targets = { "cmakeseer_example" },
            abstract_targets = {},
            json_file = vim.fs.joinpath(reply_dir, "directory-.-1.json"),
          },
        },
      },
    },
  }
end

---A valid codemodel object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Codemodel", function()
  local tmp = tmpdir()

  describe("new", function()
    it("initializes correctly", function()
      local codemodel = Codemodel.new({ major = 2, minor = 11 }, "/tmp/source", "/tmp/build", { Debug = Configuration.new("Debug", {}, {}, {}, {}) })
      assert.are.equal(object_kind.ObjectKindType.Codemodel, codemodel.kind)
      assert.are.same({ major = 2, minor = 11 }, codemodel.version)
      assert.are.equal("/tmp/source", codemodel.source)
      assert.are.equal("/tmp/build", codemodel.build)
      assert.are.equal("Debug", codemodel.configurations.Debug.name)
    end)

    it("does not share the version or configurations with the caller", function()
      local version = { major = 2, minor = 11 }
      local configurations = { Debug = Configuration.new("Debug", {}, {}, {}, {}) }

      local codemodel = Codemodel.new(version, "/tmp/source", "/tmp/build", configurations)
      version.major = 9
      configurations.Debug = nil

      assert.are.equal(2, codemodel.version.major)
      assert.are.equal("Debug", codemodel.configurations.Debug.name)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local codemodel = Codemodel.take({ major = 2, minor = 11 }, "/tmp/source", "/tmp/build", { Debug = Configuration.new("Debug", {}, {}, {}, {}) })
      assert.are.equal(object_kind.ObjectKindType.Codemodel, codemodel.kind)
      assert.are.same({ major = 2, minor = 11 }, codemodel.version)
      assert.are.equal("/tmp/source", codemodel.source)
      assert.are.equal("/tmp/build", codemodel.build)
      assert.are.equal("Debug", codemodel.configurations.Debug.name)
    end)

    -- `take` exists so that a caller that just built the configurations does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local configurations = { Debug = Configuration.new("Debug", {}, {}, {}, {}) }

      local codemodel = Codemodel.take({ major = 2, minor = 11 }, "/tmp/source", "/tmp/build", configurations)
      configurations.Debug.name = "Release"

      assert.are.equal("Release", codemodel.configurations.Debug.name)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "codemodel" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local codemodel, err = Codemodel.try_from_json(value, CODEMODEL_FILE)
        assert.is_nil(codemodel)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local codemodel, err = Codemodel.try_from_json(valid_json(), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same(valid_codemodel(), assert(codemodel))
    end)

    it("records the source and build paths the json reports", function()
      local json = valid_json({ paths = { source = "/opt/src", build = "/opt/build" } })

      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("/opt/src", assert(codemodel).source)
      assert.are.equal("/opt/build", assert(codemodel).build)
    end)

    it("resolves the jsonFile of the members against the path of the codemodel it was given", function()
      local path = "/somewhere/else/reply/codemodel-v2-1.json"

      local codemodel, err = Codemodel.try_from_json(valid_json(), path)
      assert.is_nil(err)
      assert.are.equal("/somewhere/else/reply/target-1.json", assert(codemodel).configurations.Debug.targets.cmakeseer_example.json_file)
    end)

    -- A single configuration generator writes one configuration with an empty name.
    it("accepts a codemodel with a single unnamed configuration", function()
      local json = valid_json({ configurations = { valid_configuration_json({ name = "" }) } })

      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("", assert(codemodel).configurations[""].name)
    end)

    it("keys the configurations by name", function()
      local json = valid_json({
        configurations = { valid_configuration_json({ name = "Debug" }), valid_configuration_json({ name = "Release" }) },
      })

      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({ "Debug", "Release" }, vim.fn.sort(vim.tbl_keys(assert(codemodel).configurations)))
    end)

    it("accepts a codemodel with no configurations", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ configurations = {} }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({}, assert(codemodel).configurations)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(codemodel), "futureField"))
    end)

    it("returns an error when the kind is missing", function()
      local codemodel, err = Codemodel.try_from_json(json_without("kind"), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("Incorrect kind: nil", err)
    end)

    it("returns an error when the kind is a different object kind", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ kind = "cmakeFiles" }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal('Incorrect kind: "cmakeFiles"', err)
    end)

    it("returns an error when version is missing", function()
      local codemodel, err = Codemodel.try_from_json(json_without("version"), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ version = "2.11" }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("returns an error when version.minor is not a number", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ version = { major = 2, minor = "11" } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("version.minor is wrong type: string", err)
    end)

    it("returns an error when paths is missing", function()
      local codemodel, err = Codemodel.try_from_json(json_without("paths"), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths is wrong type: nil", err)
    end)

    it("returns an error when paths is not a table", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = "/tmp/build" }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths is wrong type: string", err)
    end)

    it("returns an error when paths.source is missing", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = { build = "/tmp/build" } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("returns an error when paths.source is not a string", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = { source = 42, build = "/tmp/build" } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths.source is wrong type: number", err)
    end)

    it("returns an error when paths.build is missing", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = { source = "/tmp/source" } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths.build is wrong type: nil", err)
    end)

    it("returns an error when paths.build is not a string", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = { source = "/tmp/source", build = 42 } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths.build is wrong type: number", err)
    end)

    it("validates the source before the build", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ paths = { build = 42 } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("returns an error when configurations is missing", function()
      local codemodel, err = Codemodel.try_from_json(json_without("configurations"), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("configurations is wrong type: nil", err)
    end)

    it("returns an error when configurations is not a table", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ configurations = "Debug" }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("configurations is wrong type: string", err)
    end)

    it("returns an error when configurations is a dict instead of a list", function()
      local codemodel, err = Codemodel.try_from_json(valid_json({ configurations = { Debug = valid_configuration_json() } }), CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("configurations is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "Debug" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a configuration is a %s"):format(label), function()
        local json = valid_json()
        json.configurations = { valid_configuration_json(), value }

        local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
        assert.is_nil(codemodel)
        assert.are.equal(("configuration at index 2: json is wrong type: %s"):format(label), err)
      end)
    end

    it("reports the index of the configuration it could not parse", function()
      local json = valid_json()
      json.configurations[1].name = nil

      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("configuration at index 1: name is wrong type: nil", err)
    end)

    it("reports the error of the member of the configuration it could not resolve", function()
      local json = valid_json()
      json.configurations[1].directories[1].projectIndex = 9

      local codemodel, err = Codemodel.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(codemodel)
      assert.are.equal("configuration at index 1: directory at index 0: project_index is out of range", err)
    end)
  end)

  describe("try_from_file", function()
    --- Writes JSON to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "codemodel-v2-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("creates an instance from a valid file", function()
      local path = write(vim.json.encode(valid_json()))

      local codemodel, err = Codemodel.try_from_file(path)
      assert.is_nil(err)
      local instance = assert(codemodel)
      assert.are.equal(object_kind.ObjectKindType.Codemodel, instance.kind)
      assert.are.same({ major = 2, minor = 11 }, instance.version)
      assert.are.equal("/tmp/source", instance.source)
      assert.are.equal("/tmp/build", instance.build)
      assert.are.same(valid_codemodel(tmp.path).configurations, instance.configurations)
    end)

    it("returns the member error of the file it could not parse", function()
      local json = valid_json()
      json.configurations[1].projects[1].name = nil

      local codemodel, err = Codemodel.try_from_file(write(vim.json.encode(json)))
      assert.is_nil(codemodel)
      assert.are.equal("configuration at index 1: project at index 0: name is wrong type: nil", err)
    end)

    it("returns an error when the file does not exist", function()
      local codemodel, err = Codemodel.try_from_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(codemodel)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local codemodel, err = Codemodel.try_from_file(dir)
      assert.is_nil(codemodel)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is not JSON", function()
      local codemodel, err = Codemodel.try_from_file(write("not json"))
      assert.is_nil(codemodel)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the JSON does not describe a codemodel", function()
      local codemodel, err = Codemodel.try_from_file(write(vim.json.encode(valid_json({ kind = "cmakeFiles" }))))
      assert.is_nil(codemodel)
      assert.are.equal('Incorrect kind: "cmakeFiles"', err)
    end)
  end)
end)
