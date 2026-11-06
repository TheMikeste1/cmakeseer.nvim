local BasePreset = require("cmakeseer.cmake.preset.base_preset")

describe("BasePreset", function()
  describe("flatten", function()
    it("returns a copy unchanged when there are no parents", function()
      local preset = BasePreset.new({
        name = "child",
        environment = { FOO = "bar" },
      })
      local lookup = { child = preset }
      local flat = preset:flatten(lookup)
      assert.are.equal("child", flat.name)
      assert.are.equal("bar", flat.environment.FOO)
      assert.is_nil(flat.inherits)
    end)

    it("inherits environment entries from a single parent", function()
      local parent = BasePreset.new({
        name = "parent",
        environment = { FROM_PARENT = "parent_val" },
      })
      local child = BasePreset.new({
        name = "child",
        inherits = { "parent" },
        environment = { FROM_CHILD = "child_val" },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("child_val", flat.environment.FROM_CHILD)
      assert.are.equal("parent_val", flat.environment.FROM_PARENT)
      assert.is_nil(flat.inherits)
    end)

    it("child environment key overrides parent key", function()
      local parent = BasePreset.new({
        name = "parent",
        environment = { KEY = "parent_val" },
      })
      local child = BasePreset.new({
        name = "child",
        inherits = { "parent" },
        environment = { KEY = "child_val" },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("child_val", flat.environment.KEY)
    end)

    it("inherits across a two-level chain", function()
      local grandparent = BasePreset.new({
        name = "grandparent",
        environment = { FROM_GP = "gp_val" },
      })
      local parent = BasePreset.new({
        name = "parent",
        inherits = { "grandparent" },
        environment = { FROM_P = "p_val" },
      })
      local child = BasePreset.new({
        name = "child",
        inherits = { "parent" },
        environment = { FROM_C = "c_val" },
      })
      local lookup = { grandparent = grandparent, parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("gp_val", flat.environment.FROM_GP)
      assert.are.equal("p_val", flat.environment.FROM_P)
      assert.are.equal("c_val", flat.environment.FROM_C)
    end)

    it("earlier parent takes precedence over later parent for env keys", function()
      local p1 = BasePreset.new({ name = "p1", environment = { KEY = "from_p1" } })
      local p2 = BasePreset.new({ name = "p2", environment = { KEY = "from_p2" } })
      local child = BasePreset.new({
        name = "child",
        inherits = { "p1", "p2" },
      })
      local lookup = { p1 = p1, p2 = p2, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("from_p1", flat.environment.KEY)
    end)

    it("inherits a non-environment scalar field from parent", function()
      local parent = BasePreset.new({ name = "parent", condition = true })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.is_true(flat.condition)
    end)

    it("child scalar field overrides parent", function()
      local parent = BasePreset.new({ name = "parent", condition = true })
      local child = BasePreset.new({ name = "child", inherits = { "parent" }, condition = false })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.is_false(flat.condition)
    end)

    it("does not inherit hidden from parent (child keeps its own or none)", function()
      local parent = BasePreset.new({ name = "parent", hidden = true })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.is_nil(flat.hidden)
    end)

    it("does not inherit description or display_name from parent", function()
      local parent = BasePreset.new({
        name = "parent",
        display_name = "Parent Name",
        description = "Parent description",
      })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.is_nil(flat.display_name)
      assert.is_nil(flat.description)
    end)

    it("name is always the child's own", function()
      local parent = BasePreset.new({ name = "parent" })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("child", flat.name)
    end)

    it("does not mutate the original preset", function()
      local parent = BasePreset.new({ name = "parent", environment = { A = "1" } })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      child:flatten(lookup)
      assert.is_nil(child.environment)
      assert.are.same({ "parent" }, child.inherits)
    end)

    it("handles a missing parent gracefully", function()
      local child = BasePreset.new({ name = "child", inherits = { "nonexistent" } })
      local lookup = { child = child }
      local flat = child:flatten(lookup)
      -- Should not error; just skip the missing parent.
      assert.are.equal("child", flat.name)
    end)

    it("preset without environment is unaffected by parent with environment", function()
      local parent = BasePreset.new({ name = "parent", environment = { FROM_PARENT = "val" } })
      local child = BasePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("val", flat.environment.FROM_PARENT)
    end)
  end)
end)
