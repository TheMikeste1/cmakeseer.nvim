local Project = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.project")
local JsonDirectory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.directory")
local JsonProject = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.project")
local JsonTarget = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.target")

---The json projects CMake writes for the fixture project, as indices into the arrays of a configuration.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[]
local function json_projects()
  return {
    JsonProject.take("CodemodelExample", nil, { 1 }, { 0, 1 }, { 0, 3 }, { 0 }),
    JsonProject.take("NestedExample", 0, nil, { 2 }, { 1, 2 }, nil),
  }
end

---The json directories of the fixture project, one for each directory CMake configures.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[]
local function json_directories()
  return {
    JsonDirectory.take(".", ".", nil, { 1, 2 }, 0, { 0 }, { 0 }, "3.28", true, "/tmp/build/directory-.-1.json"),
    JsonDirectory.take("math", "math", 0, nil, 0, { 3 }, nil, "3.28", true, "/tmp/build/directory-math-1.json"),
    JsonDirectory.take("nested", "nested", 0, nil, 1, { 1, 2 }, nil, "3.28", false, "/tmp/build/directory-nested-1.json"),
  }
end

---The json targets of the fixture project.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[]
local function json_targets()
  return {
    JsonTarget.take("cmakeseer_example", "cmakeseer_example::@1", 0, 0, "/tmp/build/target-cmakeseer_example-1.json"),
    JsonTarget.take("codemodel_greet", "codemodel_greet::@2", 2, 1, "/tmp/build/target-codemodel_greet-1.json"),
    JsonTarget.take("codemodel_greeting", "codemodel_greeting::@2", 2, 1, "/tmp/build/target-codemodel_greeting-1.json"),
    JsonTarget.take("codemodel_math", "codemodel_math::@1", 1, 0, "/tmp/build/target-codemodel_math-1.json"),
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

describe("Configuration.Project", function()
  describe("new", function()
    it("initializes correctly", function()
      local project = Project.new("CodemodelExample", nil, { "NestedExample" }, { "cmakeseer_example" }, { "Threads::Threads" }, { 0, 1 })
      assert.are.equal("CodemodelExample", project.name)
      assert.is_nil(project.parent)
      assert.are.same({ "NestedExample" }, project.children)
      assert.are.same({ "cmakeseer_example" }, project.targets)
      assert.are.same({ "Threads::Threads" }, project.abstract_targets)
      assert.are.same({ 0, 1 }, project.directory_indices)
    end)

    it("leaves the parent and the directory indices absent when they are not passed", function()
      local project = Project.new("CodemodelExample", nil, {}, {}, {})
      assert.is_nil(project.parent)
      assert.is_nil(project.directory_indices)
    end)

    it("does not share the children, targets, or directory indices with the caller", function()
      local children, targets, abstract_targets = { "NestedExample" }, { "cmakeseer_example" }, { "Threads::Threads" }
      local directory_indices = { 0, 1 }

      local project = Project.new("CodemodelExample", nil, children, targets, abstract_targets, directory_indices)
      children[1] = "GoodbyeExample"
      targets[1] = "GoodbyeExample"
      abstract_targets[1] = "Goodbye::Threads"
      directory_indices[1] = 9

      assert.are.same({ "NestedExample" }, project.children)
      assert.are.same({ "cmakeseer_example" }, project.targets)
      assert.are.same({ "Threads::Threads" }, project.abstract_targets)
      assert.are.same({ 0, 1 }, project.directory_indices)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local project = Project.take("NestedExample", "CodemodelExample", {}, { "codemodel_greet" }, {}, { 2 })
      assert.are.equal("NestedExample", project.name)
      assert.are.equal("CodemodelExample", project.parent)
      assert.are.same({}, project.children)
      assert.are.same({ "codemodel_greet" }, project.targets)
      assert.are.same({}, project.abstract_targets)
      assert.are.same({ 2 }, project.directory_indices)
    end)

    -- `take` exists so that a caller that just built the name lists does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local children = { "NestedExample" }

      local project = Project.take("CodemodelExample", nil, children, {}, {}, nil)
      children[1] = "GoodbyeExample"

      assert.are.equal("GoodbyeExample", project.children[1])
    end)
  end)

  describe("try_from_json_object", function()
    it("creates an instance from the json project of the fixture", function()
      local projects = json_projects()
      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({
        name = "CodemodelExample",
        children = { "NestedExample" },
        targets = { "cmakeseer_example", "codemodel_math" },
        abstract_targets = { "Threads::Threads" },
        directory_indices = { 0, 1 },
      }, assert(project))
    end)

    it("resolves the name of the parent from the parent index", function()
      local projects = json_projects()
      local project, err = Project.try_from_json_object(projects[2], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.equal("CodemodelExample", assert(project).parent)
    end)

    it("keeps the parent index itself out of the instance", function()
      local projects = json_projects()
      local project = assert(Project.try_from_json_object(projects[2], projects, json_directories(), json_targets(), json_abstract_targets()))
      assert.is_nil(rawget(project, "parent_index"))
    end)

    it("resolves the names of the children in index order", function()
      local projects = json_projects()
      projects[1].child_indices = { 1, 0 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ "NestedExample", "CodemodelExample" }, assert(project).children)
    end)

    it("resolves the names of the targets in index order", function()
      local projects = json_projects()
      projects[1].target_indices = { 3, 0 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ "codemodel_math", "cmakeseer_example" }, assert(project).targets)
    end)

    it("resolves the names of the abstract targets in index order", function()
      local projects = json_projects()
      projects[1].abstract_target_indices = { 1, 0 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ "codemodel_imported_math", "Threads::Threads" }, assert(project).abstract_targets)
    end)

    -- CMake leaves out the index lists a project does not use, so every name list can be empty.
    it("leaves the name lists the json project omits empty", function()
      local project = JsonProject.take("NestedExample", 0, nil, { 2 }, nil, nil)

      local obj, err = Project.try_from_json_object(project, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({}, assert(obj).children)
      assert.are.same({}, assert(obj).targets)
      assert.are.same({}, assert(obj).abstract_targets)
    end)

    it("keeps the directory indices instead of resolving them into directories", function()
      local project = JsonProject.take("NestedExample", 0, nil, { 2 }, nil, nil)

      local obj, err = Project.try_from_json_object(project, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.are.same({ 2 }, assert(obj).directory_indices)
    end)

    it("leaves the directory indices absent when the json project omits them", function()
      local project = JsonProject.take("NestedExample", 0, nil, nil, nil, nil)

      local obj, err = Project.try_from_json_object(project, json_projects(), json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(err)
      assert.is_nil(assert(obj).directory_indices)
    end)

    it("does not share the directory indices with the json project", function()
      local projects = json_projects()
      local project = assert(Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets()))

      projects[1].directory_indices[1] = 9

      assert.are.same({ 0, 1 }, project.directory_indices)
    end)

    it("returns an error when the parent index is past the end of the projects", function()
      local projects = json_projects()
      projects[2].parent_index = 2

      local project, err = Project.try_from_json_object(projects[2], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("parent_index is out of range", err)
    end)

    it("returns an error when a child index is past the end of the projects", function()
      local projects = json_projects()
      projects[1].child_indices = { 0, 2 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("child_indices contains an invalid index", err)
    end)

    it("returns an error when a directory index is past the end of the directories", function()
      local projects = json_projects()
      projects[1].directory_indices = { 0, 3 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("directory_indices contains an invalid index", err)
    end)

    it("returns an error when a target index is past the end of the targets", function()
      local projects = json_projects()
      projects[1].target_indices = { 4 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("target_indices contains an invalid index", err)
    end)

    it("returns an error when an abstract target index is past the end of the abstract targets", function()
      local projects = json_projects()
      projects[1].abstract_target_indices = { 2 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("abstract_target_indices contains an invalid index", err)
    end)

    it("returns an error when there are no abstract targets to resolve an index against", function()
      local projects = json_projects()
      projects[1].abstract_target_indices = { 0 }

      local project, err = Project.try_from_json_object(projects[1], projects, json_directories(), json_targets(), {})
      assert.is_nil(project)
      assert.are.equal("abstract_target_indices contains an invalid index", err)
    end)

    it("validates the parent index before the child indices", function()
      local projects = json_projects()
      projects[2].parent_index = 9
      projects[2].child_indices = { 9 }

      local project, err = Project.try_from_json_object(projects[2], projects, json_directories(), json_targets(), json_abstract_targets())
      assert.is_nil(project)
      assert.are.equal("parent_index is out of range", err)
    end)
  end)
end)
