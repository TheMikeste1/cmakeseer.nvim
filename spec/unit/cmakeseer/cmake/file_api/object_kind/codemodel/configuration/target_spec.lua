local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.target")
local JsonDirectory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.directory")
local JsonProject = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.project")
local JsonTarget = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.target")
local tmpdir = require("spec.fixtures.tmpdir")

---The json projects of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[]
local function json_projects()
  return {
    JsonProject.take("CodemodelExample", nil, { 1 }, { 0, 1 }, { 0 }, nil),
    JsonProject.take("NestedExample", 0, nil, { 2 }, { 1, 2 }, nil),
  }
end

---The json directories of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[]
local function json_directories()
  return {
    JsonDirectory.take(".", ".", nil, { 1, 2 }, 0, { 0 }, nil, "3.28", true, "/tmp/build/directory-.-1.json"),
    JsonDirectory.take("nested", "nested", 0, nil, 1, { 1, 2 }, nil, "3.28", false, "/tmp/build/directory-nested-1.json"),
  }
end

describe("Configuration.Target", function()
  local tmp = tmpdir()

  -- A target holds only strings and numbers, so `new` has nothing to copy and builds what `take` builds.
  describe("new and take", function()
    it("initialize correctly", function()
      local expected = {
        name = "cmakeseer_example",
        id = "cmakeseer_example::@1",
        directory_index = 0,
        project = "CodemodelExample",
        json_file = "/tmp/build/target-1.json",
      }

      assert.are.same(expected, Target.new("cmakeseer_example", "cmakeseer_example::@1", 0, "CodemodelExample", "/tmp/build/target-1.json"))
      assert.are.same(expected, Target.take("cmakeseer_example", "cmakeseer_example::@1", 0, "CodemodelExample", "/tmp/build/target-1.json"))
    end)
  end)

  describe("try_from_json_object", function()
    it("creates an instance from a json target", function()
      local targets = { JsonTarget.take("cmakeseer_example", "cmakeseer_example::@1", 0, 0, "/tmp/build/target-1.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(err)
      assert.are.same({
        name = "cmakeseer_example",
        id = "cmakeseer_example::@1",
        directory_index = 0,
        project = "CodemodelExample",
        json_file = "/tmp/build/target-1.json",
      }, assert(target))
    end)

    it("resolves the name of the project from the project index", function()
      local targets = { JsonTarget.take("codemodel_greet", "codemodel_greet::@2", 1, 1, "/tmp/build/target-2.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(err)
      assert.are.equal("NestedExample", assert(target).project)
    end)

    it("keeps the directory index instead of resolving it into a directory", function()
      local targets = { JsonTarget.take("codemodel_greet", "codemodel_greet::@2", 1, 1, "/tmp/build/target-2.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(err)
      assert.are.equal(1, assert(target).directory_index)
    end)

    it("returns an error when the project index is past the end of the projects", function()
      local targets = { JsonTarget.take("cmakeseer_example", "id", 0, 2, "/tmp/build/target-1.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(target)
      assert.are.equal("project_index is out of range", err)
    end)

    it("returns an error when the directory index is past the end of the directories", function()
      local targets = { JsonTarget.take("cmakeseer_example", "id", 2, 0, "/tmp/build/target-1.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(target)
      assert.are.equal("directory_index is out of range", err)
    end)

    it("validates the project index before the directory index", function()
      local targets = { JsonTarget.take("cmakeseer_example", "id", 9, 9, "/tmp/build/target-1.json") }

      local target, err = Target.try_from_json_object(targets[1], json_projects(), json_directories())
      assert.is_nil(target)
      assert.are.equal("project_index is out of range", err)
    end)
  end)

  describe("try_read_codemodel", function()
    it("decodes the target object CMake wrote", function()
      local json_file = vim.fs.joinpath(tmp.path, "target-cmakeseer_example-1fbd134ad5da528f3158.json")
      require("spec.utils").write_file(
        json_file,
        vim.json.encode({
          codemodelVersion = { major = 2, minor = 11 },
          name = "cmakeseer_example",
          id = "cmakeseer_example::@1",
          type = "EXECUTABLE",
          paths = { source = ".", build = "." },
          backtraceGraph = {
            nodes = { { file = 0 } },
            commands = { "install" },
            files = { "CMakeLists.txt" },
          },
        })
      )

      local target = Target.take("cmakeseer_example", "id", 0, "CodemodelExample", json_file)
      local json, err = target:try_read_codemodel()
      assert.is_nil(err)
      assert.are.equal("EXECUTABLE", assert(json).type)
    end)

    it("returns an error when the target object is gone", function()
      local target = Target.take("cmakeseer_example", "id", 0, "CodemodelExample", vim.fs.joinpath(tmp.path, "missing.json"))

      local json, err = target:try_read_codemodel()
      assert.is_nil(json)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)
  end)
end)
