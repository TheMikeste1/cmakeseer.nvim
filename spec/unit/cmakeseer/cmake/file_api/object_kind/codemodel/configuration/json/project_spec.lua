local Project = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.project")

---A valid project object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    name = "CodemodelExample",
    childIndexes = { 1, 2 },
    directoryIndexes = { 0 },
    targetIndexes = { 0, 3 },
    abstractTargetIndexes = { 1 },
  }, overrides or {})
end

---The project CMake writes, as parsed from their json.
---@return table<string, any> json
local function valid_project()
  return {
    name = "CodemodelExample",
    parent_index = nil,
    child_indices = { 1, 2 },
    directory_indices = { 0 },
    target_indices = { 0, 3 },
    abstract_target_indices = { 1 },
  }
end

---A valid project object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("Configuration.Json.Project", function()
  describe("new", function()
    it("initializes correctly", function()
      local project = Project.new("CodemodelExample", 0, { 1, 2 }, { 0 }, { 0, 3 }, { 1 })
      assert.are.equal("CodemodelExample", project.name)
      assert.are.equal(0, project.parent_index)
      assert.are.same({ 1, 2 }, project.child_indices)
      assert.are.same({ 0 }, project.directory_indices)
      assert.are.same({ 0, 3 }, project.target_indices)
      assert.are.same({ 1 }, project.abstract_target_indices)
    end)

    it("leaves the members that are not passed absent", function()
      local project = Project.new("CodemodelExample")
      assert.is_nil(project.parent_index)
      assert.is_nil(project.child_indices)
      assert.is_nil(project.directory_indices)
      assert.is_nil(project.target_indices)
      assert.is_nil(project.abstract_target_indices)
    end)

    it("does not share the index lists with the caller", function()
      local child_indices, directory_indices = { 1 }, { 0 }
      local target_indices, abstract_target_indices = { 0 }, { 1 }

      local project = Project.new("CodemodelExample", 0, child_indices, directory_indices, target_indices, abstract_target_indices)
      child_indices[1] = 9
      directory_indices[1] = 9
      target_indices[1] = 9
      abstract_target_indices[1] = 9

      assert.are.same({ 1 }, project.child_indices)
      assert.are.same({ 0 }, project.directory_indices)
      assert.are.same({ 0 }, project.target_indices)
      assert.are.same({ 1 }, project.abstract_target_indices)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local project = Project.take("CodemodelExample", 0, { 1 }, { 0 }, { 3 }, { 1 })
      assert.are.equal("CodemodelExample", project.name)
      assert.are.equal(0, project.parent_index)
      assert.are.same({ 1 }, project.child_indices)
      assert.are.same({ 0 }, project.directory_indices)
      assert.are.same({ 3 }, project.target_indices)
      assert.are.same({ 1 }, project.abstract_target_indices)
    end)

    -- `take` exists so that a caller that just built the index lists does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local child_indices = { 1 }

      local project = Project.take("CodemodelExample", nil, child_indices)
      child_indices[1] = 9

      assert.are.equal(9, project.child_indices[1])
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "CodemodelExample" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local project, err = Project.try_from_json(value)
        assert.is_nil(project)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local project, err = Project.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_project(), assert(project))
    end)

    it("keeps the parent index when the json has one", function()
      local project, err = Project.try_from_json(valid_json({ parentIndex = 0 }))
      assert.is_nil(err)
      assert.are.equal(0, assert(project).parent_index)
    end)

    -- CMake leaves out every index list a project does not use.
    it("leaves the index lists the json omits absent", function()
      local project, err = Project.try_from_json(json_without("childIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(project).child_indices)

      project, err = Project.try_from_json(json_without("directoryIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(project).directory_indices)

      project, err = Project.try_from_json(json_without("targetIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(project).target_indices)

      project, err = Project.try_from_json(json_without("abstractTargetIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(project).abstract_target_indices)
    end)

    it("accepts an empty index list", function()
      local project, err = Project.try_from_json(valid_json({ childIndexes = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(project).child_indices)
    end)

    it("keeps an index of 0", function()
      local project, err = Project.try_from_json(valid_json({ directoryIndexes = { 0 } }))
      assert.is_nil(err)
      assert.are.same({ 0 }, assert(project).directory_indices)
    end)

    it("keeps a multi digit index", function()
      local project, err = Project.try_from_json(valid_json({ targetIndexes = { 10, 11 } }))
      assert.is_nil(err)
      assert.are.same({ 10, 11 }, assert(project).target_indices)
    end)

    it("preserves the order of an index list", function()
      local project, err = Project.try_from_json(valid_json({ targetIndexes = { 3, 0 } }))
      assert.is_nil(err)
      assert.are.same({ 3, 0 }, assert(project).target_indices)
    end)

    it("ignores unknown fields", function()
      local project, err = Project.try_from_json(vim.tbl_extend("force", valid_json(), { futureField = "ignored" }))
      assert.is_nil(err)
      assert.is_nil(rawget(assert(project), "futureField"))
    end)

    it("returns an error when name is missing", function()
      local project, err = Project.try_from_json(json_without("name"))
      assert.is_nil(project)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local project, err = Project.try_from_json(valid_json({ name = 42 }))
      assert.is_nil(project)
      assert.are.equal("name is wrong type: number", err)
    end)

    for _, entry in ipairs({ { "0", "string" }, { true, "boolean" }, { vim.NIL, "userdata" } }) do
      local value, label = entry[1], entry[2]
      it(("returns an error when parentIndex is a %s"):format(label), function()
        local project, err = Project.try_from_json(valid_json({ parentIndex = value }))
        assert.is_nil(project)
        assert.are.equal(("parentIndex is wrong type: %s"):format(label), err)
      end)
    end

    it("returns an error when parentIndex is negative", function()
      local project, err = Project.try_from_json(valid_json({ parentIndex = -1 }))
      assert.is_nil(project)
      assert.are.equal("parentIndex is invalid: -1", err)
    end)

    -- Every index list reports the same failures, so every one of them is exercised with the same values.
    for _, field in ipairs({ "childIndexes", "directoryIndexes", "targetIndexes", "abstractTargetIndexes" }) do
      for _, entry in ipairs({
        { "string", "0", "string" },
        { "dict", { ["0"] = 42 }, "table" },
      }) do
        local label, value, type_name = entry[1], entry[2], entry[3]
        it(("returns an error when %s is a %s"):format(field, label), function()
          local project, err = Project.try_from_json(valid_json({ [field] = value }))
          assert.is_nil(project)
          assert.are.equal(("%s is wrong type: %s"):format(field, type_name), err)
        end)
      end

      it(("returns an error when an element of %s is not a number"):format(field), function()
        local project, err = Project.try_from_json(valid_json({ [field] = { 0, "0" } }))
        assert.is_nil(project)
        assert.are.equal(("%s at 2 is wrong type: string"):format(field), err)
      end)

      it(("returns an error when an element of %s is negative"):format(field), function()
        local project, err = Project.try_from_json(valid_json({ [field] = { -1 } }))
        assert.is_nil(project)
        assert.are.equal(("%s at 1 is invalid: -1"):format(field), err)
      end)
    end

    it("reports the position of the invalid element of an index list", function()
      local project, err = Project.try_from_json(valid_json({ targetIndexes = { 0, 1, 2, "3" } }))
      assert.is_nil(project)
      assert.are.equal("targetIndexes at 4 is wrong type: string", err)
    end)

    it("validates the index lists in the order CMake documents them", function()
      local json = valid_json()
      json.childIndexes = { 0, "0" }
      json.directoryIndexes = { 0, "0" }
      json.targetIndexes = { 0, "0" }
      json.abstractTargetIndexes = { 0, "0" }

      local project, err = Project.try_from_json(json)
      assert.is_nil(project)
      assert.are.equal("childIndexes at 2 is wrong type: string", err)
    end)
  end)
end)
