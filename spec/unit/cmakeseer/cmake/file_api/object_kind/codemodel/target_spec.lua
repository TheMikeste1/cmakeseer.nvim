local BacktraceGraph = require("cmakeseer.cmake.file_api.object_kind.codemodel.backtrace_graph")
local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.target")

local TargetType = Target.Type

---A valid backtrace graph object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function backtrace_graph_json(overrides)
  return vim.tbl_extend("force", {
    nodes = {
      { file = 0 },
      { file = 0, line = 48, command = 0, parent = 0 },
    },
    commands = { "install" },
    files = { "CMakeLists.txt" },
  }, overrides or {})
end

---The backtrace graph the fixture json describes.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph graph
local function backtrace_graph()
  return BacktraceGraph.take({
    { file = "CMakeLists.txt", line = nil, command = nil, parent = nil },
    { file = "CMakeLists.txt", line = 48, command = "install", parent = 1 },
  })
end

---A valid codemodel version, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function version_json(overrides)
  return vim.tbl_extend("force", { major = 2, minor = 11 }, overrides or {})
end

---A valid target JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    codemodelVersion = version_json(),
    name = "cmakeseer_example",
    id = "cmakeseer_example::@1",
    type = "EXECUTABLE",
    imported = false,
    ["local"] = false,
    abstract = false,
    symbolic = false,
    backtrace = 0,
    folder = { name = "Helpers" },
    paths = { source = ".", build = "." },
    nameOnDisk = "cmakeseer_example",
    artifacts = { "cmakeseer_example" },
    generatorProvided = false,
    backtraceGraph = backtrace_graph_json(),
  }, overrides or {})
end

---The target CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target target
local function valid_target()
  return {
    codemodel_version = { major = 2, minor = 11 },
    name = "cmakeseer_example",
    id = "cmakeseer_example::@1",
    type = TargetType.Executable,
    imported = false,
    ["local"] = false,
    abstract = false,
    symbolic = false,
    backtrace_index = 0,
    folder = "Helpers",
    source = ".",
    build = ".",
    name_on_disk = "cmakeseer_example",
    artifacts = { "cmakeseer_example" },
    generator_provided = false,
    backtrace_graph = backtrace_graph(),
  }
end

---A valid target JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a target object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target? obj, string? err
local function try_from_json(overrides)
  return Target.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target", function()
  describe("Type", function()
    it("defines every target type CMake reports", function()
      assert.are.same({
        Executable = "EXECUTABLE",
        StaticLibrary = "STATIC_LIBRARY",
        SharedLibrary = "SHARED_LIBRARY",
        ModuleLibrary = "MODULE_LIBRARY",
        ObjectLibrary = "OBJECT_LIBRARY",
        InterfaceLibrary = "INTERFACE_LIBRARY",
        Utility = "UTILITY",
      }, TargetType)
    end)
  end)

  describe("new", function()
    it("initializes correctly", function()
      local target = Target.new(
        { major = 2, minor = 11 },
        "cmakeseer_example",
        "cmakeseer_example::@1",
        TargetType.Executable,
        false,
        false,
        false,
        false,
        nil,
        nil,
        ".",
        ".",
        "cmakeseer_example",
        {},
        false,
        nil,
        nil,
        backtrace_graph(),
        nil,
        nil,
        nil,
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {},
        {}
      )
      assert.are.same({ major = 2, minor = 11 }, assert(target.codemodel_version))
      assert.are.equal("cmakeseer_example", target.name)
      assert.are.equal("cmakeseer_example::@1", target.id)
      assert.are.equal(TargetType.Executable, target.type)
      assert.is_false(target.imported)
      assert.is_false(target["local"])
      assert.is_false(target.abstract)
      assert.is_false(target.symbolic)
      assert.is_nil(target.backtrace_index)
      assert.is_nil(target.folder)
      assert.are.equal(".", target.source)
      assert.are.equal(".", target.build)
      assert.are.equal("cmakeseer_example", target.name_on_disk)
      assert.are.same({}, target.artifacts)
      assert.is_false(target.generator_provided)
    end)

    it("does not share the version or artifacts with the caller", function()
      local version = { major = 2, minor = 11 }
      local artifacts = { "cmakeseer_example" }
      local graph = backtrace_graph()

      local target = Target.new(version, "cmakeseer_example", "id", TargetType.Executable, false, false, false, false, nil, nil, ".", ".", nil, artifacts, false, nil, nil, graph, nil, nil, nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})
      version.major = 9
      artifacts[1] = "other"
      graph.nodes[1].file = "other/CMakeLists.txt"

      assert.are.equal(2, assert(target.codemodel_version).major)
      assert.are.same({ "cmakeseer_example" }, target.artifacts)
      assert.are.equal("CMakeLists.txt", target.backtrace_graph.nodes[1].file)
    end)
  end)

  describe("take", function()
    -- `take` exists so that a caller that just parsed the subobjects does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local graph = backtrace_graph()

      local target = Target.take(nil, "cmakeseer_example", "id", TargetType.Executable, false, false, false, false, nil, nil, ".", ".", nil, nil, false, nil, nil, graph, nil, nil, nil, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {})
      graph.nodes[1].file = "other/CMakeLists.txt"

      assert.are.equal("other/CMakeLists.txt", target.backtrace_graph.nodes[1].file)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "target" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local target, err = Target.try_from_json(value)
        assert.is_nil(target)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local target, err = Target.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_target(), assert(target))
    end)

    it("records the version of the codemodel it is a part of", function()
      local target, err = try_from_json({ codemodelVersion = version_json({ major = 2, minor = 3 }) })
      assert.is_nil(err)
      assert.are.same({ major = 2, minor = 3 }, assert(target).codemodel_version)
    end)

    it("leaves the codemodel version absent when the json omits it", function()
      local target, err = Target.try_from_json(json_without("codemodelVersion"))
      assert.is_nil(err)
      assert.is_nil(assert(target).codemodel_version)
    end)

    it("returns an error when the codemodel version is not a table", function()
      local target, err = try_from_json({ codemodelVersion = "2.11" })
      assert.is_nil(target)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("records the name the json reports", function()
      local target, err = try_from_json({ name = "codemodel_math" })
      assert.is_nil(err)
      assert.are.equal("codemodel_math", assert(target).name)
    end)

    it("returns an error when name is missing", function()
      local target, err = Target.try_from_json(json_without("name"))
      assert.is_nil(target)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local target, err = try_from_json({ name = 42 })
      assert.is_nil(target)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("records the id the json reports", function()
      local target, err = try_from_json({ id = "codemodel_math::@2" })
      assert.is_nil(err)
      assert.are.equal("codemodel_math::@2", assert(target).id)
    end)

    it("returns an error when id is missing", function()
      local target, err = Target.try_from_json(json_without("id"))
      assert.is_nil(target)
      assert.are.equal("id is wrong type: nil", err)
    end)

    it("returns an error when id is not a string", function()
      local target, err = try_from_json({ id = 42 })
      assert.is_nil(target)
      assert.are.equal("id is wrong type: number", err)
    end)

    for _, entry in ipairs({
      { "EXECUTABLE", TargetType.Executable },
      { "STATIC_LIBRARY", TargetType.StaticLibrary },
      { "SHARED_LIBRARY", TargetType.SharedLibrary },
      { "MODULE_LIBRARY", TargetType.ModuleLibrary },
      { "OBJECT_LIBRARY", TargetType.ObjectLibrary },
      { "INTERFACE_LIBRARY", TargetType.InterfaceLibrary },
      { "UTILITY", TargetType.Utility },
    }) do
      local type_str, expected = entry[1], entry[2]
      it(("records the type %s"):format(type_str), function()
        local target, err = try_from_json({ type = type_str })
        assert.is_nil(err)
        assert.are.equal(expected, assert(target).type)
      end)
    end

    it("returns an error when type is missing", function()
      local target, err = Target.try_from_json(json_without("type"))
      assert.is_nil(target)
      assert.are.equal("type is wrong type: nil", err)
    end)

    it("returns an error when type is not a string", function()
      local target, err = try_from_json({ type = 42 })
      assert.is_nil(target)
      assert.are.equal("type is wrong type: number", err)
    end)

    it("returns an error when type is not a value CMake writes", function()
      local target, err = try_from_json({ type = "INVALID" })
      assert.is_nil(target)
      assert.are.equal("type is invalid: INVALID", err)
    end)

    it("records the imported flag the json reports", function()
      local target, err = try_from_json({ imported = true })
      assert.is_nil(err)
      assert.is_true(assert(target).imported)
    end)

    it("leaves the imported flag false when the json omits it", function()
      local target, err = Target.try_from_json(json_without("imported"))
      assert.is_nil(err)
      assert.is_false(assert(target).imported)
    end)

    it("returns an error when imported is not a boolean", function()
      local target, err = try_from_json({ imported = "yes" })
      assert.is_nil(target)
      assert.are.equal("imported is wrong type: string", err)
    end)

    it("records the local flag the json reports", function()
      local target, err = try_from_json({ ["local"] = true })
      assert.is_nil(err)
      assert.is_true(assert(target)["local"])
    end)

    it("leaves the local flag false when the json omits it", function()
      local target, err = Target.try_from_json(json_without("local"))
      assert.is_nil(err)
      assert.is_false(assert(target)["local"])
    end)

    it("returns an error when local is not a boolean", function()
      local target, err = try_from_json({ ["local"] = 1 })
      assert.is_nil(target)
      assert.are.equal("local is wrong type: number", err)
    end)

    it("records the abstract flag the json reports", function()
      local target, err = try_from_json({ abstract = true })
      assert.is_nil(err)
      assert.is_true(assert(target).abstract)
    end)

    it("leaves the abstract flag false when the json omits it", function()
      local target, err = Target.try_from_json(json_without("abstract"))
      assert.is_nil(err)
      assert.is_false(assert(target).abstract)
    end)

    it("returns an error when abstract is not a boolean", function()
      local target, err = try_from_json({ abstract = "yes" })
      assert.is_nil(target)
      assert.are.equal("abstract is wrong type: string", err)
    end)

    it("records the symbolic flag the json reports", function()
      local target, err = try_from_json({ symbolic = true })
      assert.is_nil(err)
      assert.is_true(assert(target).symbolic)
    end)

    it("leaves the symbolic flag false when the json omits it", function()
      local target, err = Target.try_from_json(json_without("symbolic"))
      assert.is_nil(err)
      assert.is_false(assert(target).symbolic)
    end)

    it("returns an error when symbolic is not a boolean", function()
      local target, err = try_from_json({ symbolic = "yes" })
      assert.is_nil(target)
      assert.are.equal("symbolic is wrong type: string", err)
    end)

    it("records the backtrace index the json reports", function()
      for _, index in ipairs({ 0, 1 }) do
        local target, err = try_from_json({ backtrace = index })
        assert.is_nil(err)
        assert.are.equal(index, assert(target).backtrace_index)
      end
    end)

    it("leaves the backtrace index absent when the json omits it", function()
      local target, err = Target.try_from_json(json_without("backtrace"))
      assert.is_nil(err)
      assert.is_nil(assert(target).backtrace_index)
    end)

    it("returns an error when the backtrace index is not a number", function()
      local target, err = try_from_json({ backtrace = "0" })
      assert.is_nil(target)
      assert.are.equal("backtrace is wrong type: string", err)
    end)

    it("records the folder name the json reports", function()
      local target, err = try_from_json({ folder = { name = "Helpers" } })
      assert.is_nil(err)
      assert.are.equal("Helpers", assert(target).folder)
    end)

    it("leaves the folder absent when the json omits it", function()
      local target, err = Target.try_from_json(json_without("folder"))
      assert.is_nil(err)
      assert.is_nil(assert(target).folder)
    end)

    it("returns an error when folder is not a table", function()
      local target, err = try_from_json({ folder = "Helpers" })
      assert.is_nil(target)
      assert.are.equal("folder is wrong type: string", err)
    end)

    it("returns an error when folder.name is missing", function()
      local target, err = try_from_json({ folder = {} })
      assert.is_nil(target)
      assert.are.equal("folder.name is wrong type: nil", err)
    end)

    it("returns an error when folder.name is not a string", function()
      local target, err = try_from_json({ folder = { name = 42 } })
      assert.is_nil(target)
      assert.are.equal("folder.name is wrong type: number", err)
    end)

    it("records the source path the json reports", function()
      local target, err = try_from_json({ paths = { source = "math", build = "." } })
      assert.is_nil(err)
      assert.are.equal("math", assert(target).source)
    end)

    it("records the build path the json reports", function()
      local target, err = try_from_json({ paths = { source = ".", build = "math" } })
      assert.is_nil(err)
      assert.are.equal("math", assert(target).build)
    end)

    it("returns an error when paths is missing", function()
      local target, err = Target.try_from_json(json_without("paths"))
      assert.is_nil(target)
      assert.are.equal("paths is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "." },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when paths is %s"):format(label), function()
        local target, err = try_from_json({ paths = value })
        assert.is_nil(target)
        assert.are.equal(("paths is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when paths.source is missing", function()
      local target, err = try_from_json({ paths = { build = "." } })
      assert.is_nil(target)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("returns an error when paths.source is not a string", function()
      local target, err = try_from_json({ paths = { source = 42, build = "." } })
      assert.is_nil(target)
      assert.are.equal("paths.source is wrong type: number", err)
    end)

    it("returns an error when paths.build is missing", function()
      local target, err = try_from_json({ paths = { source = "." } })
      assert.is_nil(target)
      assert.are.equal("paths.build is wrong type: nil", err)
    end)

    it("returns an error when paths.build is not a string", function()
      local target, err = try_from_json({ paths = { source = ".", build = true } })
      assert.is_nil(target)
      assert.are.equal("paths.build is wrong type: boolean", err)
    end)

    it("records the name on disk the json reports", function()
      local target, err = try_from_json({ nameOnDisk = "cmakeseer_example.exe" })
      assert.is_nil(err)
      assert.are.equal("cmakeseer_example.exe", assert(target).name_on_disk)
    end)

    it("leaves the name on disk absent when the json omits it", function()
      local target, err = Target.try_from_json(json_without("nameOnDisk"))
      assert.is_nil(err)
      assert.is_nil(assert(target).name_on_disk)
    end)

    it("returns an error when nameOnDisk is not a string", function()
      local target, err = try_from_json({ nameOnDisk = 42 })
      assert.is_nil(target)
      assert.are.equal("nameOnDisk is wrong type: number", err)
    end)

    it("records the artifacts the json reports", function()
      local target, err = try_from_json({ artifacts = { "cmakeseer_example", "cmakeseer_example.pdb" } })
      assert.is_nil(err)
      assert.are.same({ "cmakeseer_example", "cmakeseer_example.pdb" }, assert(target).artifacts)
    end)

    it("leaves the artifacts absent when the json omits them", function()
      local target, err = Target.try_from_json(json_without("artifacts"))
      assert.is_nil(err)
      assert.is_nil(assert(target).artifacts)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "cmakeseer_example" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when artifacts is %s"):format(label), function()
        local target, err = try_from_json({ artifacts = value })
        assert.is_nil(target)
        assert.are.equal(("artifacts is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when an artifact is not a string", function()
      local target, err = try_from_json({ artifacts = { "cmakeseer_example", 42 } })
      assert.is_nil(target)
      assert.are.equal("artifacts[2] is wrong type: number", err)
    end)

    it("records the generator provided flag the json reports", function()
      local target, err = try_from_json({ generatorProvided = true })
      assert.is_nil(err)
      assert.is_true(assert(target).generator_provided)
    end)

    it("leaves the generator provided flag false when the json omits it", function()
      local target, err = Target.try_from_json(json_without("generatorProvided"))
      assert.is_nil(err)
      assert.is_false(assert(target).generator_provided)
    end)

    it("returns an error when generatorProvided is not a boolean", function()
      local target, err = try_from_json({ generatorProvided = "yes" })
      assert.is_nil(target)
      assert.are.equal("generatorProvided is wrong type: string", err)
    end)

    it("records the backtrace graph the json reports", function()
      local target, err = try_from_json({ backtraceGraph = backtrace_graph_json({ commands = { "add_subdirectory" } }) })
      assert.is_nil(err)
      assert.are.same(
        BacktraceGraph.take({
          { file = "CMakeLists.txt", line = nil, command = nil, parent = nil },
          { file = "CMakeLists.txt", line = 48, command = "add_subdirectory", parent = 1 },
        }).nodes,
        assert(target).backtrace_graph.nodes
      )
    end)

    it("returns an error when the backtrace graph is missing", function()
      local target, err = Target.try_from_json(json_without("backtraceGraph"))
      assert.is_nil(target)
      assert.are.equal("backtraceGraph is invalid: json is wrong type: nil", err)
    end)

    it("returns the error of the backtrace graph it could not parse", function()
      local target, err = try_from_json({ backtraceGraph = backtrace_graph_json({ nodes = { {} } }) })
      assert.is_nil(target)
      assert.are.equal("backtraceGraph is invalid: node at index 1: file is wrong type: nil", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local target, err = Target.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(target), "futureField"))
    end)

    it("validates the members of a target in the order CMake documents them", function()
      local json = valid_json()
      for field in pairs(json) do
        json[field] = nil
      end

      local target, err = Target.try_from_json(json)
      assert.is_nil(target)
      assert.are.equal("name is wrong type: nil", err)
    end)
  end)
end)
