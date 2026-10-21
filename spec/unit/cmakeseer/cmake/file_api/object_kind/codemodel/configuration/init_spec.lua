local Configuration = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration")
local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.directory")
local Project = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.project")
local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.target")

--- The codemodel file the relative jsonFile values of the configuration are resolved against.
local CODEMODEL_FILE = vim.fs.joinpath("/tmp/build/.cmake/api/v1/reply", "codemodel-v2-0123456789abcdef.json")

--- The reply directory the relative jsonFile values of the configuration resolve into.
local REPLY_DIR = vim.fs.dirname(CODEMODEL_FILE)

---A valid configuration object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    name = "Debug",
    projects = {
      {
        name = "CodemodelExample",
        childIndexes = { 1 },
        directoryIndexes = { 0, 1 },
        targetIndexes = { 0, 3, 4 },
        abstractTargetIndexes = { 0 },
      },
      { name = "NestedExample", parentIndex = 0, directoryIndexes = { 2 }, targetIndexes = { 1, 2 } },
    },
    targets = {
      { name = "cmakeseer_example", id = "cmakeseer_example::@1", directoryIndex = 0, projectIndex = 0, jsonFile = "target-cmakeseer_example-1.json" },
      { name = "codemodel_greet", id = "codemodel_greet::@2", directoryIndex = 2, projectIndex = 1, jsonFile = "target-codemodel_greet-1.json" },
      { name = "codemodel_greeting", id = "codemodel_greeting::@2", directoryIndex = 2, projectIndex = 1, jsonFile = "target-codemodel_greeting-1.json" },
      { name = "codemodel_math", id = "codemodel_math::@1", directoryIndex = 1, projectIndex = 0, jsonFile = "target-codemodel_math-1.json" },
      { name = "generate_config", id = "generate_config::@1", directoryIndex = 0, projectIndex = 0, jsonFile = "target-generate_config-1.json" },
    },
    abstractTargets = {
      { name = "Threads::Threads", id = "Threads::Threads::@1", directoryIndex = 0, projectIndex = 0, jsonFile = "target-Threads__Threads-1.json" },
      { name = "codemodel_imported_math", id = "codemodel_imported_math::@1", directoryIndex = 1, projectIndex = 0, jsonFile = "target-codemodel_imported_math-1.json" },
    },
    directories = {
      {
        source = ".",
        build = ".",
        childIndexes = { 1, 2 },
        projectIndex = 0,
        targetIndexes = { 0, 4 },
        abstractTargetIndexes = { 0 },
        minimumCMakeVersion = { string = "3.28" },
        hasInstallRule = true,
        jsonFile = "directory-.-1.json",
      },
      {
        source = "math",
        build = "math",
        parentIndex = 0,
        projectIndex = 0,
        targetIndexes = { 3 },
        minimumCMakeVersion = { string = "3.28" },
        hasInstallRule = true,
        jsonFile = "directory-math-1.json",
      },
      {
        source = "nested",
        build = "nested",
        parentIndex = 0,
        projectIndex = 1,
        targetIndexes = { 1, 2 },
        minimumCMakeVersion = { string = "3.28" },
        jsonFile = "directory-nested-1.json",
      },
    },
  }, overrides or {})
end

--- The projects of the configuration, as parsed from their json.
---@return table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project>
local function valid_projects()
  return {
    CodemodelExample = {
      name = "CodemodelExample",
      children = { "NestedExample" },
      targets = { "cmakeseer_example", "codemodel_math", "generate_config" },
      abstract_targets = { "Threads::Threads" },
      directory_indices = { 0, 1 },
    },
    NestedExample = {
      name = "NestedExample",
      parent = "CodemodelExample",
      children = {},
      targets = { "codemodel_greet", "codemodel_greeting" },
      abstract_targets = {},
      directory_indices = { 2 },
    },
  }
end

--- The targets of the configuration, as parsed from their json.
---@return table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target>
local function valid_targets()
  return {
    cmakeseer_example = {
      name = "cmakeseer_example",
      id = "cmakeseer_example::@1",
      directory_index = 0,
      project = "CodemodelExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-cmakeseer_example-1.json"),
    },
    codemodel_greet = {
      name = "codemodel_greet",
      id = "codemodel_greet::@2",
      directory_index = 2,
      project = "NestedExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-codemodel_greet-1.json"),
    },
    codemodel_greeting = {
      name = "codemodel_greeting",
      id = "codemodel_greeting::@2",
      directory_index = 2,
      project = "NestedExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-codemodel_greeting-1.json"),
    },
    codemodel_math = {
      name = "codemodel_math",
      id = "codemodel_math::@1",
      directory_index = 1,
      project = "CodemodelExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-codemodel_math-1.json"),
    },
    generate_config = {
      name = "generate_config",
      id = "generate_config::@1",
      directory_index = 0,
      project = "CodemodelExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-generate_config-1.json"),
    },
  }
end

--- The abstract targets of the configuration, as parsed from their json.
---@return table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target>
local function valid_abstract_targets()
  return {
    ["Threads::Threads"] = {
      name = "Threads::Threads",
      id = "Threads::Threads::@1",
      directory_index = 0,
      project = "CodemodelExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-Threads__Threads-1.json"),
    },
    codemodel_imported_math = {
      name = "codemodel_imported_math",
      id = "codemodel_imported_math::@1",
      directory_index = 1,
      project = "CodemodelExample",
      json_file = vim.fs.joinpath(REPLY_DIR, "target-codemodel_imported_math-1.json"),
    },
  }
end

--- The directories of the configuration, as parsed from their json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory[]
local function valid_directories()
  return {
    {
      source = ".",
      build = ".",
      minimum_cmake_version = Directory.MinimumCMakeVersion.new(3, 28),
      has_install_rule = true,
      project = "CodemodelExample",
      targets = { "cmakeseer_example", "generate_config" },
      abstract_targets = { "Threads::Threads" },
      child_indices = { 1, 2 },
      json_file = vim.fs.joinpath(REPLY_DIR, "directory-.-1.json"),
    },
    {
      source = "math",
      build = "math",
      minimum_cmake_version = Directory.MinimumCMakeVersion.new(3, 28),
      has_install_rule = true,
      project = "CodemodelExample",
      targets = { "codemodel_math" },
      abstract_targets = {},
      parent_index = 0,
      json_file = vim.fs.joinpath(REPLY_DIR, "directory-math-1.json"),
    },
    {
      source = "nested",
      build = "nested",
      minimum_cmake_version = Directory.MinimumCMakeVersion.new(3, 28),
      has_install_rule = false,
      project = "NestedExample",
      targets = { "codemodel_greet", "codemodel_greeting" },
      abstract_targets = {},
      parent_index = 0,
      json_file = vim.fs.joinpath(REPLY_DIR, "directory-nested-1.json"),
    },
  }
end

describe("Configuration", function()
  describe("new", function()
    it("initializes correctly", function()
      local configuration = Configuration.new("Debug", { A = Project.new("A", nil, {}, {}, {}) }, { a = Target.new("a", "id", 0, "A", "/d.json") }, {}, {})
      assert.are.equal("Debug", configuration.name)
      assert.are.equal("A", configuration.projects.A.name)
      assert.are.equal("a", configuration.targets.a.name)
      assert.are.same({}, configuration.abstract_targets)
      assert.are.same({}, configuration.directories)
    end)

    it("does not share the projects, targets, or directories with the caller", function()
      local projects = { A = Project.new("A", nil, {}, {}, {}) }
      local targets = { a = Target.new("a", "id", 0, "A", "/d.json") }
      local abstract_targets = { b = Target.new("b", "id", 0, "A", "/d.json") }
      local directories = { Directory.new(".", ".", nil, false, "A", {}, {}, nil, nil, "/d.json") }

      local configuration = Configuration.new("Debug", projects, targets, abstract_targets, directories)
      projects.A = nil
      targets.a = nil
      abstract_targets.b = nil
      directories[1].source = "other"

      assert.are.equal("A", configuration.projects.A.name)
      assert.are.equal("a", configuration.targets.a.name)
      assert.are.equal("b", configuration.abstract_targets.b.name)
      assert.are.equal(".", configuration.directories[1].source)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local configuration = Configuration.take("Debug", { A = Project.new("A", nil, {}, {}, {}) }, { a = Target.new("a", "id", 0, "A", "/d.json") }, {}, {})
      assert.are.equal("Debug", configuration.name)
      assert.are.equal("A", configuration.projects.A.name)
      assert.are.equal("a", configuration.targets.a.name)
      assert.are.same({}, configuration.abstract_targets)
      assert.are.same({}, configuration.directories)
    end)

    -- `take` exists so that a caller that just built the members does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local projects = { A = Project.new("A", nil, {}, {}, {}) }
      local directories = { Directory.new(".", ".", nil, false, "A", {}, {}, nil, nil, "/d.json") }

      local configuration = Configuration.take("Debug", projects, {}, {}, directories)
      projects.A.name = "B"
      directories[1].source = "other"

      assert.are.equal("B", configuration.projects.A.name)
      assert.are.equal("other", configuration.directories[1].source)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "Debug" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local configuration, err = Configuration.try_from_json(value, CODEMODEL_FILE)
        assert.is_nil(configuration)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local configuration, err = Configuration.try_from_json(valid_json(), CODEMODEL_FILE)
      assert.is_nil(err)
      local instance = assert(configuration)
      assert.are.equal("Debug", instance.name)
      assert.are.same(valid_projects(), instance.projects)
      assert.are.same(valid_targets(), instance.targets)
      assert.are.same(valid_abstract_targets(), instance.abstract_targets)
      assert.are.same(valid_directories(), instance.directories)
    end)

    it("keys the projects, targets, and abstract targets by name", function()
      local configuration = assert(Configuration.try_from_json(valid_json(), CODEMODEL_FILE))
      assert.are.same({ "CodemodelExample", "NestedExample" }, vim.fn.sort(vim.tbl_keys(configuration.projects)))
      assert.are.same({
        "cmakeseer_example",
        "codemodel_greet",
        "codemodel_greeting",
        "codemodel_math",
        "generate_config",
      }, vim.fn.sort(vim.tbl_keys(configuration.targets)))
      assert.are.same({ "Threads::Threads", "codemodel_imported_math" }, vim.fn.sort(vim.tbl_keys(configuration.abstract_targets)))
    end)

    it("keeps the directories in the order CMake reports them", function()
      local json = valid_json()
      json.directories = { json.directories[3], json.directories[2], json.directories[1] }

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      local directories = assert(configuration).directories
      assert.are.equal("nested", directories[1].source)
      assert.are.equal("math", directories[2].source)
      assert.are.equal(".", directories[3].source)
    end)

    it("keeps a configuration name that is empty, as a single configuration generator writes", function()
      local configuration, err = Configuration.try_from_json(valid_json({ name = "" }), CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.equal("", assert(configuration).name)
    end)

    it("accepts a configuration with no projects, targets, or directories", function()
      local configuration, err = Configuration.try_from_json({ name = "Debug", projects = {}, targets = {}, abstractTargets = {}, directories = {} }, CODEMODEL_FILE)
      assert.is_nil(err)
      local instance = assert(configuration)
      assert.are.same({}, instance.projects)
      assert.are.same({}, instance.targets)
      assert.are.same({}, instance.abstract_targets)
      assert.are.same({}, instance.directories)
    end)

    -- CMake only started reporting abstractTargets in 3.27.
    it("defaults the abstract targets to none when the json omits them", function()
      local json = valid_json()
      json.abstractTargets = nil
      for _, project in ipairs(json.projects) do
        project.abstractTargetIndexes = nil
      end
      for _, directory in ipairs(json.directories) do
        directory.abstractTargetIndexes = nil
      end

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.are.same({}, assert(configuration).abstract_targets)
      assert.are.same({}, assert(configuration).directories[1].abstract_targets)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(configuration), "futureField"))
    end)

    it("returns an error when name is missing", function()
      local json = valid_json()
      json.name = nil

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local configuration, err = Configuration.try_from_json(valid_json({ name = 42 }), CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("validates the members in the order CMake documents them", function()
      local configuration, err = Configuration.try_from_json(
        valid_json({
          name = 42,
          projects = "not a list",
          targets = "not a list",
          abstractTargets = "not a list",
          directories = "not a list",
        }),
        CODEMODEL_FILE
      )
      assert.is_nil(configuration)
      assert.are.equal("name is wrong type: number", err)
    end)

    -- Each member is a list of objects, so each one reports the same failures under its own name.
    -- Each member is a list of objects, so each one reports the same failures under its own name.
    for _, member in ipairs({
      { field = "projects", label = "project", successor = "targets" },
      { field = "targets", label = "target", successor = "abstractTargets" },
      { field = "abstractTargets", label = "abstract target", successor = "directories", defaults_to_empty = true },
      { field = "directories", label = "directory" },
    }) do
      local field, label = member.field, member.label

      -- The members CMake always writes are required; the one it only writes since a later version is not.
      if not member.defaults_to_empty then
        it(("returns an error when %s is missing"):format(field), function()
          local json = valid_json()
          json[field] = nil

          local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
          assert.is_nil(configuration)
          assert.are.equal(("%s is wrong type: nil"):format(field), err)
        end)
      end

      it(("returns an error when %s is not a table"):format(field), function()
        local configuration, err = Configuration.try_from_json(valid_json({ [field] = "not a list" }), CODEMODEL_FILE)
        assert.is_nil(configuration)
        assert.are.equal(("%s is wrong type: string"):format(field), err)
      end)

      it(("returns an error when %s is a dict instead of a list"):format(field), function()
        local configuration, err = Configuration.try_from_json(valid_json({ [field] = { ["0"] = 42 } }), CODEMODEL_FILE)
        assert.is_nil(configuration)
        assert.are.equal(("%s is wrong type: table"):format(field), err)
      end)

      it(("returns an error when an element of %s is not an object"):format(field), function()
        local configuration, err = Configuration.try_from_json(valid_json({ [field] = { 42 } }), CODEMODEL_FILE)
        assert.is_nil(configuration)
        assert.are.equal(("%s at index 0: json is wrong type: number"):format(label), err)
      end)

      it(("reports the zero-based index of the invalid element of %s"):format(field), function()
        local json = valid_json()
        json[field] = { json[field][1], 43 }

        local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
        assert.is_nil(configuration)
        assert.are.equal(("%s at index 1: json is wrong type: number"):format(label), err)
      end)

      if member.successor then
        it(("validates %s before %s"):format(field, member.successor), function()
          local json = valid_json()
          json[field] = { 42 }
          json[member.successor] = { 42 }

          local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
          assert.is_nil(configuration)
          assert.are.equal(("%s at index 0: json is wrong type: number"):format(label), err)
        end)
      end
    end

    it("returns an error when a directory has a negative project index", function()
      local json = valid_json()
      json.directories[1].projectIndex = -1

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("directory at index 0: projectIndex is invalid: -1", err)
    end)

    it("returns an error when a target has a negative directory index", function()
      local json = valid_json()
      json.targets[1].directoryIndex = -1

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("target at index 0: directoryIndex is invalid: -1", err)
    end)

    it("reports the index of the project that resolves an out of range index", function()
      local json = valid_json()
      json.projects[1].childIndexes = { 9 }

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("project at index 0: child_indices contains an invalid index", err)
    end)

    it("reports the index of the target that resolves an out of range index", function()
      local json = valid_json()
      json.targets[2].projectIndex = 9

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("target at index 1: project_index is out of range", err)
    end)

    it("reports the index of the abstract target that resolves an out of range index", function()
      local json = valid_json()
      json.abstractTargets[2].directoryIndex = 9

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("abstract target at index 1: directory_index is out of range", err)
    end)

    it("reports the index of the directory that resolves an out of range index", function()
      local json = valid_json()
      json.directories[3].projectIndex = 9

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("directory at index 2: project_index is out of range", err)
    end)

    it("reports the target whose jsonFile is of the wrong type", function()
      local json = valid_json()
      json.targets[1].jsonFile = 42

      local configuration, err = Configuration.try_from_json(json, CODEMODEL_FILE)
      assert.is_nil(configuration)
      assert.are.equal("target at index 0: jsonFile is wrong type: number", err)
    end)
  end)
end)
