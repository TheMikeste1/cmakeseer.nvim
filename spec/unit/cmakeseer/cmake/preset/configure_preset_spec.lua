local ConfigurePreset = require("cmakeseer.cmake.preset.configure_preset")

describe("ConfigurePreset", function()
  describe("flatten", function()
    it("returns a ConfigurePreset instance", function()
      local preset = ConfigurePreset.new({ name = "p", generator = "Ninja" })
      local flat = preset:flatten({ p = preset })
      assert.are.equal(ConfigurePreset, getmetatable(flat))
    end)

    it("inherits generator from parent", function()
      local parent = ConfigurePreset.new({ name = "parent", generator = "Ninja" })
      local child = ConfigurePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("Ninja", flat.generator)
    end)

    it("child generator overrides parent generator", function()
      local parent = ConfigurePreset.new({ name = "parent", generator = "Ninja" })
      local child = ConfigurePreset.new({ name = "child", inherits = { "parent" }, generator = "Unix Makefiles" })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("Unix Makefiles", flat.generator)
    end)

    it("inherits environment entries and binary_dir from parent", function()
      local parent = ConfigurePreset.new({
        name = "parent",
        environment = { MY_VAR = "hello" },
        binary_dir = "/tmp/build",
      })
      local child = ConfigurePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("hello", flat.environment.MY_VAR)
      assert.are.equal("/tmp/build", flat.binary_dir)
    end)

    it("does not share environment table with parent", function()
      local parent = ConfigurePreset.new({ name = "parent", environment = { A = "1" } })
      local child = ConfigurePreset.new({ name = "child", inherits = { "parent" } })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      flat.environment.A = "mutated"
      assert.are.equal("1", parent.environment.A)
    end)

    it("unions cacheVariables entries from parent; distinct keys survive", function()
      local parent = ConfigurePreset.new({
        name = "parent",
        cache_variables = { BASE_VAR = "base_value", SHARED = "from_base" },
      })
      local child = ConfigurePreset.new({
        name = "child",
        inherits = { "parent" },
        cache_variables = { CHILD_VAR = "child_value" },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("base_value", flat.cache_variables.BASE_VAR)
      assert.are.equal("child_value", flat.cache_variables.CHILD_VAR)
      assert.are.equal("from_base", flat.cache_variables.SHARED)
    end)

    it("child cacheVariables override parent entries with the same key", function()
      local parent = ConfigurePreset.new({
        name = "parent",
        cache_variables = { SHARED = "from_base" },
      })
      local child = ConfigurePreset.new({
        name = "child",
        inherits = { "parent" },
        cache_variables = { SHARED = "from_child" },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("from_child", flat.cache_variables.SHARED)
    end)

    it("earlier parent is preferred over later parent for cacheVariables conflicts", function()
      local p1 = ConfigurePreset.new({ name = "p1", cache_variables = { SHARED = "from_p1" } })
      local p2 = ConfigurePreset.new({ name = "p2", cache_variables = { SHARED = "from_p2" } })
      local child = ConfigurePreset.new({ name = "child", inherits = { "p1", "p2" } })
      local lookup = { p1 = p1, p2 = p2, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("from_p1", flat.cache_variables.SHARED)
    end)

    it("object-valued cacheVariables entries survive inheritance by key", function()
      local parent = ConfigurePreset.new({
        name = "parent",
        cache_variables = {
          TYPED = { type = "BOOL", value = true },
          PLAIN = "from_base",
        },
      })
      local child = ConfigurePreset.new({
        name = "child",
        inherits = { "parent" },
        cache_variables = { PLAIN = "from_child" },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.same({ type = "BOOL", value = true }, flat.cache_variables.TYPED)
      assert.are.equal("from_child", flat.cache_variables.PLAIN)
    end)

    it("null cacheVariable in child unsets inherited value", function()
      local parent = ConfigurePreset.new({
        name = "parent",
        cache_variables = { TYPED = { type = "BOOL", value = true }, PLAIN = "from_base" },
      })
      local child = ConfigurePreset.new({
        name = "child",
        inherits = { "parent" },
        cache_variables = { TYPED = vim.NIL, PLAIN = vim.NIL },
      })
      local lookup = { parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal(vim.NIL, flat.cache_variables.TYPED)
      assert.are.equal(vim.NIL, flat.cache_variables.PLAIN)
    end)

    it("two-level cacheVariables union keeps grandparent-only entries", function()
      local grandparent = ConfigurePreset.new({ name = "grandparent", cache_variables = { GP_VAR = "gp" } })
      local parent = ConfigurePreset.new({
        name = "parent",
        inherits = { "grandparent" },
        cache_variables = { P_VAR = "p" },
      })
      local child = ConfigurePreset.new({
        name = "child",
        inherits = { "parent" },
        cache_variables = { C_VAR = "c" },
      })
      local lookup = { grandparent = grandparent, parent = parent, child = child }
      local flat = child:flatten(lookup)
      assert.are.equal("gp", flat.cache_variables.GP_VAR)
      assert.are.equal("p", flat.cache_variables.P_VAR)
      assert.are.equal("c", flat.cache_variables.C_VAR)
    end)
  end)
end)
