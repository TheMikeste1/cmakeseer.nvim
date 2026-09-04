local WorkflowPreset = require("cmakeseer.cmake.preset.workflow_preset")

describe("cmakeseer.cmake.preset.WorkflowPreset", function()
  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local preset, err = WorkflowPreset.try_from_json("not a table")
      assert.is_nil(preset)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local preset1, err1 = WorkflowPreset.try_from_json({})
      assert.is_nil(preset1)
      assert.are.equal("Could not find name in preset", err1)

      local preset2, err2 = WorkflowPreset.try_from_json({ name = 123 })
      assert.is_nil(preset2)
      assert.are.equal("name must be a string", err2)
    end)

    it("returns nil when steps is missing or empty or not a table", function()
      local preset1, err1 = WorkflowPreset.try_from_json({ name = "wf" })
      assert.is_nil(preset1)
      assert.are.equal("Could not find steps in workflow preset", err1)

      local preset2, err2 = WorkflowPreset.try_from_json({ name = "wf", steps = "invalid" })
      assert.is_nil(preset2)
      assert.are.equal("steps must be a non-empty list", err2)

      local preset3, err3 = WorkflowPreset.try_from_json({ name = "wf", steps = {} })
      assert.is_nil(preset3)
      assert.are.equal("steps must be a non-empty list", err3)
    end)

    it("validates step structure", function()
      local preset1, err1 = WorkflowPreset.try_from_json({ name = "wf", steps = { "not a table" } })
      assert.is_nil(preset1)
      assert.are.equal("step at index 1 must be an object", err1)

      local preset2, err2 = WorkflowPreset.try_from_json({ name = "wf", steps = { { name = "step1" } } })
      assert.is_nil(preset2)
      assert.are.equal("step at index 1 requires a type string", err2)

      local preset3, err3 = WorkflowPreset.try_from_json({ name = "wf", steps = { { type = "configure" } } })
      assert.is_nil(preset3)
      assert.are.equal("step at index 1 requires a name string", err3)
    end)

    it("requires the first step to be configure", function()
      local preset, err = WorkflowPreset.try_from_json({
        name = "wf",
        steps = { { type = "build", name = "b1" } },
      })
      assert.is_nil(preset)
      assert.are.equal("The first step in a workflow preset must be configure", err)
    end)

    it("validates step types", function()
      local preset, err = WorkflowPreset.try_from_json({
        name = "wf",
        steps = {
          { type = "configure", name = "c1" },
          { type = "deploy", name = "d1" },
        },
      })
      assert.is_nil(preset)
      assert.are.equal("step type 'deploy' at index 2 is invalid", err)
    end)

    it("succeeds with valid steps", function()
      local valid_steps = {
        { type = "configure", name = "c1" },
        { type = "build", name = "b1" },
        { type = "test", name = "t1" },
        { type = "package", name = "p1" },
      }
      local preset, err = WorkflowPreset.try_from_json({
        name = "wf",
        steps = valid_steps,
        displayName = "Workflow 1",
        description = "Run full workflow",
        vendor = { ide = true },
      })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.equal("wf", preset.name)
      assert.are.same(valid_steps, preset.steps)
      assert.are.equal("Workflow 1", preset.display_name)
      assert.are.equal("Run full workflow", preset.description)
      assert.are.same({ ide = true }, preset.vendor)
    end)

    it("validates vendor, displayName, and description types", function()
      local preset1, err1 = WorkflowPreset.try_from_json({
        name = "wf",
        steps = { { type = "configure", name = "c" } },
        vendor = "invalid",
      })
      assert.is_nil(preset1)
      assert.are.equal("vendor must be an object", err1)

      local preset2, err2 = WorkflowPreset.try_from_json({
        name = "wf",
        steps = { { type = "configure", name = "c" } },
        displayName = 123,
      })
      assert.is_nil(preset2)
      assert.are.equal("displayName must be a string", err2)

      local preset3, err3 = WorkflowPreset.try_from_json({
        name = "wf",
        steps = { { type = "configure", name = "c" } },
        description = 123,
      })
      assert.is_nil(preset3)
      assert.are.equal("description must be a string", err3)
    end)
  end)
end)
