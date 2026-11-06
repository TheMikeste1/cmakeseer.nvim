local BuildPreset = require("cmakeseer.cmake.preset.build_preset")

describe("BuildPreset", function()
  describe("flatten", function()
    it("returns a BuildPreset instance", function()
      local preset = BuildPreset.new({ name = "p" })
      local flat = preset:flatten({ p = preset })
      assert.are.equal(BuildPreset, getmetatable(flat))
    end)

    it("inherits configure_preset from parent", function()
      local parent = BuildPreset.new({ name = "parent", configure_preset = "my-configure" })
      local child = BuildPreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("my-configure", flat.configure_preset)
    end)

    it("child configure_preset overrides parent", function()
      local parent = BuildPreset.new({ name = "parent", configure_preset = "base" })
      local child = BuildPreset.new({ name = "child", inherits = { "parent" }, configure_preset = "override" })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("override", flat.configure_preset)
    end)

    it("inherits environment from parent", function()
      local parent = BuildPreset.new({ name = "parent", environment = { CC = "clang" } })
      local child = BuildPreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("clang", flat.environment.CC)
    end)

    it("inherits jobs from parent", function()
      local parent = BuildPreset.new({ name = "parent", jobs = 8 })
      local child = BuildPreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal(8, flat.jobs)
    end)

    it("two-level chain works", function()
      local gp = BuildPreset.new({ name = "gp", environment = { FROM_GP = "gp" } })
      local parent = BuildPreset.new({ name = "parent", inherits = { "gp" }, jobs = 4 })
      local child = BuildPreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { gp = gp, parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("gp", flat.environment.FROM_GP)
      assert.are.equal(4, flat.jobs)
    end)

    it("no inheritance leaves preset unchanged", function()
      local preset = BuildPreset.new({ name = "standalone", jobs = 2, configure_preset = "cfg" })
      local flat = preset:flatten({ standalone = preset })
      assert.are.equal(2, flat.jobs)
      assert.are.equal("cfg", flat.configure_preset)
      assert.is_nil(flat.inherits)
    end)
  end)
end)
