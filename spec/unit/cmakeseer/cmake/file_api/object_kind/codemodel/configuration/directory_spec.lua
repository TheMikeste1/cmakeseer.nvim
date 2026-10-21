local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.directory")
local JsonDirectory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.directory")
local JsonProject = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.project")
local JsonTarget = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.target")
local tmpdir = require("spec.fixtures.tmpdir")

local MinimumCMakeVersion = Directory.MinimumCMakeVersion

---The json projects of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[]
local function json_projects()
  return {
    JsonProject.take("CodemodelExample", nil, { 1 }, { 0, 1 }, { 0, 3 }, { 0 }),
    JsonProject.take("NestedExample", 0, nil, { 2 }, { 1, 2 }, nil),
  }
end

---The json directories of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[]
local function json_directories()
  return {
    JsonDirectory.take(".", ".", nil, { 1, 2 }, 0, { 0, 1 }, { 0 }, "3.28", true, "/tmp/build/directory-.-1.json"),
    JsonDirectory.take("math", "math", 0, nil, 0, { 2 }, nil, "3.28", true, "/tmp/build/directory-math-1.json"),
    JsonDirectory.take("nested", "nested", 0, nil, 1, { 3, 4 }, nil, "3.28", false, "/tmp/build/directory-nested-1.json"),
  }
end

---The json targets of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[]
local function json_targets()
  return {
    JsonTarget.take("cmakeseer_example", "cmakeseer_example::@1", 0, 0, "/tmp/build/target-cmakeseer_example-1.json"),
    JsonTarget.take("generate_config", "generate_config::@1", 0, 0, "/tmp/build/target-generate_config-1.json"),
    JsonTarget.take("codemodel_math", "codemodel_math::@1", 1, 0, "/tmp/build/target-codemodel_math-1.json"),
    JsonTarget.take("codemodel_math_objects", "codemodel_math_objects::@1", 1, 0, "/tmp/build/target-codemodel_math_objects-1.json"),
    JsonTarget.take("codemodel_greet", "codemodel_greet::@2", 2, 1, "/tmp/build/target-codemodel_greet-1.json"),
  }
end

---The json abstract targets of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[]
local function json_abstract_targets()
  return {
    JsonTarget.take("Threads::Threads", "Threads::Threads::@1", 0, 0, "/tmp/build/target-Threads__Threads-1.json"),
    JsonTarget.take("codemodel_imported_math", "codemodel_imported_math::@1", 1, 0, "/tmp/build/target-imported-1.json"),
  }
end

describe("Configuration.Directory", function()
  local tmp = tmpdir()

  describe("MinimumCMakeVersion", function()
    -- A version holds only numbers and a string, so `new` has nothing to copy and builds what `take` builds.
    it("new and take initialize correctly", function()
      local expected = { major = 3, minor = 28, patch = 1, tweak = 2, suffix = "-rc1" }

      assert.are.same(expected, MinimumCMakeVersion.new(3, 28, 1, 2, "-rc1"))
      assert.are.same(expected, MinimumCMakeVersion.take(3, 28, 1, 2, "-rc1"))
    end)

    it("leaves the optional members absent when they are not passed", function()
      local version = MinimumCMakeVersion.new(3, 28)
      assert.is_nil(version.patch)
      assert.is_nil(version.tweak)
      assert.is_nil(version.suffix)
    end)
  end)

  describe("new", function()
    it("initializes correctly", function()
      local directory = Directory.new("math", "math", MinimumCMakeVersion.new(3, 28), true, "CodemodelExample", { "codemodel_math" }, { "codemodel_imported_math" }, 0, nil, "/tmp/build/directory-math-1.json")
      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
      assert.are.equal(3, assert(directory.minimum_cmake_version).major)
      assert.is_true(directory.has_install_rule)
      assert.are.equal("CodemodelExample", directory.project)
      assert.are.same({ "codemodel_math" }, directory.targets)
      assert.are.same({ "codemodel_imported_math" }, directory.abstract_targets)
      assert.are.equal(0, directory.parent_index)
      assert.is_nil(directory.child_indices)
      assert.are.equal("/tmp/build/directory-math-1.json", directory.json_file)
    end)

    it("leaves the optional members absent when they are not passed", function()
      local directory = Directory.new(".", ".", nil, false, "CodemodelExample", {}, {}, nil, nil, "/d.json")
      assert.is_nil(directory.minimum_cmake_version)
      assert.is_nil(directory.parent_index)
      assert.is_nil(directory.child_indices)
    end)

    it("does not share the targets, abstract targets, or child indices with the caller", function()
      local targets, abstract_targets, child_indices = { "codemodel_math" }, { "Threads::Threads" }, { 1 }

      local directory = Directory.new(".", ".", nil, false, "CodemodelExample", targets, abstract_targets, nil, child_indices, "/d.json")
      targets[1] = "GoodbyeExample"
      abstract_targets[1] = "Goodbye::Threads"
      child_indices[1] = 9

      assert.are.same({ "codemodel_math" }, directory.targets)
      assert.are.same({ "Threads::Threads" }, directory.abstract_targets)
      assert.are.same({ 1 }, directory.child_indices)
    end)

    it("copies the minimum CMake version the caller passed", function()
      local version = MinimumCMakeVersion.new(3, 28)
      local directory = Directory.new(".", ".", version, false, "CodemodelExample", {}, {}, nil, nil, "/d.json")

      version.major = 9

      assert.are.equal(3, assert(directory.minimum_cmake_version).major)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local directory = Directory.take("math", "math", MinimumCMakeVersion.new(3, 28), true, "CodemodelExample", { "codemodel_math" }, {}, 0, { 2 }, "/d.json")
      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
      assert.are.equal(28, assert(directory.minimum_cmake_version).minor)
      assert.is_true(directory.has_install_rule)
      assert.are.equal("CodemodelExample", directory.project)
      assert.are.same({ "codemodel_math" }, directory.targets)
      assert.are.same({}, directory.abstract_targets)
      assert.are.equal(0, directory.parent_index)
      assert.are.same({ 2 }, directory.child_indices)
      assert.are.equal("/d.json", directory.json_file)
    end)

    -- `take` exists so that a caller that just built the name lists does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local child_indices = { 1 }

      local directory = Directory.take(".", ".", nil, false, "CodemodelExample", {}, {}, nil, child_indices, "/d.json")
      child_indices[1] = 9

      assert.are.equal(9, directory.child_indices[1])
    end)
  end)

  describe("try_from_json_object", function()
    it("creates an instance from the json directory of the fixture", function()
      local directories = json_directories()
      local directory, err = Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({
        source = ".",
        build = ".",
        minimum_cmake_version = MinimumCMakeVersion.new(3, 28),
        has_install_rule = true,
        project = "CodemodelExample",
        targets = { "cmakeseer_example", "generate_config" },
        abstract_targets = { "Threads::Threads" },
        parent_index = nil,
        child_indices = { 1, 2 },
        json_file = "/tmp/build/directory-.-1.json",
      }, assert(directory))
    end)

    it("resolves the name of the project from the project index", function()
      local directories = json_directories()
      local directory, err = Directory.try_from_json_object(directories[3], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.equal("NestedExample", assert(directory).project)
    end)

    it("keeps the parent index instead of resolving it into a directory", function()
      local directories = json_directories()
      local directory, err = Directory.try_from_json_object(directories[2], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.equal(0, assert(directory).parent_index)
    end)

    it("resolves the names of the targets in index order", function()
      local directories = json_directories()
      directories[3].target_indices = { 4, 3 }

      local directory, err = Directory.try_from_json_object(directories[3], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ "codemodel_greet", "codemodel_math_objects" }, assert(directory).targets)
    end)

    it("resolves the names of the abstract targets in index order", function()
      local directories = json_directories()
      directories[1].abstract_target_indices = { 1, 0 }

      local directory, err = Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ "codemodel_imported_math", "Threads::Threads" }, assert(directory).abstract_targets)
    end)

    -- CMake leaves out the index lists a directory does not use, so every name list can be empty.
    it("leaves the name lists the json directory omits empty", function()
      local directory = JsonDirectory.take(".", ".", nil, nil, 0, nil, nil, nil, false, "/d.json")

      local obj, err = Directory.try_from_json_object(directory, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({}, assert(obj).targets)
      assert.are.same({}, assert(obj).abstract_targets)
    end)

    it("does not share the child indices with the json directory", function()
      local directories = json_directories()
      local directory = assert(Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets()))

      directories[1].child_indices[1] = 9

      assert.are.same({ 1, 2 }, directory.child_indices)
    end)

    --- A json directory whose minimum CMake version is the given string.
    ---@param version? string
    ---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory
    local function directory_with_minimum(version)
      return JsonDirectory.take(".", ".", nil, nil, 0, nil, nil, version, false, "/d.json")
    end

    --- The minimum CMake version of the given json directory.
    ---@param version? string
    ---@return table<string, any>? minimum, string? err
    local function try_minimum(version)
      local obj, err = Directory.try_from_json_object(directory_with_minimum(version), json_projects(), json_directories(), json_targets(), json_abstract_targets())
      if obj == nil then
        return nil, err
      end
      return obj.minimum_cmake_version, nil
    end

    it("parses a version without a patch", function()
      local minimum, err = try_minimum("3.28")
      assert.is_nil(err)
      assert.are.same({ major = 3, minor = 28 }, assert(minimum))
    end)

    it("parses a version with a patch", function()
      local minimum, err = try_minimum("3.28.4")
      assert.is_nil(err)
      assert.are.equal(4, assert(minimum).patch)
      assert.is_nil(assert(minimum).tweak)
      assert.is_nil(assert(minimum).suffix)
    end)

    it("parses a version with a patch and a tweak", function()
      local minimum, err = try_minimum("3.28.4.1")
      assert.is_nil(err)
      assert.are.equal(4, assert(minimum).patch)
      assert.are.equal(1, assert(minimum).tweak)
      assert.is_nil(assert(minimum).suffix)
    end)

    it("parses a version with a suffix", function()
      local minimum, err = try_minimum("3.28-rc1")
      assert.is_nil(err)
      assert.is_nil(assert(minimum).patch)
      assert.are.equal("-rc1", assert(minimum).suffix)
    end)

    it("parses a version with a patch and a suffix", function()
      local minimum, err = try_minimum("3.28.4-rc1")
      assert.is_nil(err)
      assert.are.equal(4, assert(minimum).patch)
      assert.is_nil(assert(minimum).tweak)
      assert.are.equal("-rc1", assert(minimum).suffix)
    end)

    it("parses a multi digit version", function()
      local minimum, err = try_minimum("12.203.45.67-beta.2")
      assert.is_nil(err)
      assert.are.same({ major = 12, minor = 203, patch = 45, tweak = 67, suffix = "-beta.2" }, assert(minimum))
    end)

    it("parses a version with a zero minor", function()
      local minimum, err = try_minimum("3.0")
      assert.is_nil(err)
      assert.are.same({ major = 3, minor = 0 }, assert(minimum))
    end)

    it("leaves the minimum CMake version absent when the json directory omits it", function()
      local minimum, err = try_minimum(nil)
      assert.is_nil(err)
      assert.is_nil(minimum)
    end)

    for _, entry in ipairs({ { "3", "no minor" }, { "3.x", "a non numeric minor" }, { "abc", "no numbers" }, { "", "nothing" } }) do
      local version, label = entry[1], entry[2]
      it(("returns an error when the minimum CMake version has %s"):format(label), function()
        local minimum, err = try_minimum(version)
        assert.is_nil(minimum)
        assert.are.equal(("minimum_cmake_version is invalid: %s"):format(version), err)
      end)
    end

    it("returns an error when the parent index is past the end of the directories", function()
      local directories = json_directories()
      directories[2].parent_index = 3

      local directory, err = Directory.try_from_json_object(directories[2], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(directory)
      assert.are.equal("parent_index is out of range", err)
    end)

    it("returns an error when a child index is past the end of the directories", function()
      local directories = json_directories()
      directories[1].child_indices = { 3 }

      local directory, err = Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(directory)
      assert.are.equal("child_indices contains an invalid index", err)
    end)

    it("returns an error when the project index is past the end of the projects", function()
      local directories = json_directories()
      directories[2].project_index = 2

      local directory, err = Directory.try_from_json_object(directories[2], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(directory)
      assert.are.equal("project_index is out of range", err)
    end)

    it("returns an error when a target index is past the end of the targets", function()
      local directories = json_directories()
      directories[1].target_indices = { 0, 5 }

      local directory, err = Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(directory)
      assert.are.equal("target_indices contains an invalid index", err)
    end)

    it("returns an error when an abstract target index is past the end of the abstract targets", function()
      local directories = json_directories()
      directories[1].abstract_target_indices = { 2 }

      local directory, err = Directory.try_from_json_object(directories[1], json_projects(), directories, json_targets(), json_abstract_targets())
      assert.is_nil(directory)
      assert.are.equal("abstract_target_indices contains an invalid index", err)
    end)

    it("validates the child indices before the minimum CMake version", function()
      local directory = JsonDirectory.take(".", ".", nil, { 9 }, 0, nil, nil, "nonsense", false, "/d.json")

      local obj, err = Directory.try_from_json_object(directory, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(obj)
      assert.are.equal("child_indices contains an invalid index", err)
    end)

    it("validates the target indices before the abstract target indices", function()
      local directory = JsonDirectory.take(".", ".", nil, nil, 0, { 9 }, { 9 }, nil, false, "/d.json")

      local obj, err = Directory.try_from_json_object(directory, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(obj)
      assert.are.equal("target_indices contains an invalid index", err)
    end)
  end)

  describe("try_read_codemodel", function()
    it("decodes the directory object CMake wrote", function()
      local json_file = vim.fs.joinpath(tmp.path, "directory-nested-3ac2b34c77e427cba49e.json")
      require("spec.utils").write_file(
        json_file,
        vim.json.encode({
          codemodelVersion = { major = 2, minor = 11 },
          paths = { source = "nested", build = "nested" },
          installers = {},
          backtraceGraph = {
            nodes = { { file = 0 } },
            commands = { "install" },
            files = { "CMakeLists.txt" },
          },
        })
      )

      local directory = Directory.take("nested", "nested", nil, false, "NestedExample", {}, {}, 0, nil, json_file)
      local json, err = directory:try_read_codemodel()
      assert.is_nil(err)
      assert.are.equal("nested", assert(json).source)
    end)

    it("returns an error when the directory object is gone", function()
      local directory = Directory.take("nested", "nested", nil, false, "NestedExample", {}, {}, 0, nil, vim.fs.joinpath(tmp.path, "missing.json"))

      local json, err = directory:try_read_codemodel()
      assert.is_nil(json)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)
  end)
end)
