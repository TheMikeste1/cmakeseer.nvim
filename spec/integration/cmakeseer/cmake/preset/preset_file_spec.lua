local PresetFile = require("cmakeseer.cmake.preset.preset_file")

--- Absolute path to a named fixture directory.
---@param name string
---@return string
local function fixture_dir(name)
  -- Busted runs from the project root (where justfile lives).
  local project_root = vim.fn.getcwd()
  return vim.fs.joinpath(project_root, "spec", "fixtures", "cmake", "presets", name)
end

--- Loads and expands a preset file by name from a fixture directory.
---@param dir string Absolute fixture directory path.
---@param filename? string Defaults to "CMakePresets.json".
---@return cmakeseer.cmake.preset.PresetFile
local function load_expanded(dir, filename)
  filename = filename or "CMakePresets.json"
  local path = vim.fs.joinpath(dir, filename)
  local file, err = PresetFile.try_from_file(path)
  assert(file ~= nil, ("Failed to load %s: %s"):format(path, err or "unknown error"))
  return file:expanded()
end

--- Finds a preset by name in a list, erroring if it is not present.
---@param list table[]
---@param name string
---@return table preset The preset with the given name.
local function find_preset(list, name)
  for _, p in ipairs(list) do
    if p.name == name then
      return p
    end
  end
  error(("preset %q not found"):format(name), 2)
end

describe("PresetFile (integration)", function()
  describe("simple preset with no inheritance", function()
    local expanded

    lazy_setup(function()
      expanded = load_expanded(fixture_dir("simple"))
    end)

    it("loads configure presets", function()
      assert.is_not_nil(expanded.configure_presets)
      assert.are.equal(1, #expanded.configure_presets)
    end)

    it("preserves generator", function()
      local p = find_preset(expanded.configure_presets, "default")
      assert.are.equal("Ninja", p.generator)
    end)

    it("expands ${sourceDir} macro in binary_dir", function()
      local p = find_preset(expanded.configure_presets, "default")
      -- ${sourceDir} expands to the project root from cmakeseer config, but in
      -- a test environment it resolves to whatever get_config() returns.
      -- We just verify it no longer contains the raw macro token.
      assert.is_false(p.binary_dir:find("%${sourceDir}") ~= nil)
    end)

    it("preserves environment entries", function()
      local p = find_preset(expanded.configure_presets, "default")
      assert.are.equal("hello", p.environment.MY_VAR)
    end)

    it("loads build presets", function()
      assert.is_not_nil(expanded.build_presets)
      local p = find_preset(expanded.build_presets, "default-build")
      assert.are.equal("default", p.configure_preset)
      assert.are.equal(4, p.jobs)
    end)
  end)

  describe("preset inheritance", function()
    local expanded

    lazy_setup(function()
      expanded = load_expanded(fixture_dir("inheritance"))
    end)

    describe("configure presets", function()
      it("child inherits environment from middle inheriting from base", function()
        local p = find_preset(expanded.configure_presets, "child")
        assert.are.equal("base_val", p.environment.FROM_BASE)
        assert.are.equal("middle_val", p.environment.FROM_MIDDLE)
        assert.are.equal("child_val", p.environment.FROM_CHILD)
      end)

      it("middle's SHARED_KEY overrides base's SHARED_KEY (closer parent wins)", function()
        local p = find_preset(expanded.configure_presets, "child")
        assert.are.equal("from_middle", p.environment.SHARED_KEY)
      end)

      it("child inherits generator from base through middle", function()
        local p = find_preset(expanded.configure_presets, "child")
        assert.are.equal("Ninja", p.generator)
      end)

      it("${presetName} in binary_dir expands to the preset's own name", function()
        local p = find_preset(expanded.configure_presets, "child")
        assert.is_not_nil(p.binary_dir)
        assert.is_not_nil(p.binary_dir:find("child$"))
      end)

      it("override-generator replaces parent generator", function()
        local p = find_preset(expanded.configure_presets, "override-generator")
        assert.are.equal("Unix Makefiles", p.generator)
      end)

      it("override-generator still inherits binary_dir from base", function()
        local p = find_preset(expanded.configure_presets, "override-generator")
        assert.is_not_nil(p.binary_dir)
        assert.is_not_nil(p.binary_dir:find("override%-generator$"))
      end)

      it("multi-child has env from both parents (first parent wins on conflict)", function()
        local p = find_preset(expanded.configure_presets, "multi-child")
        assert.are.equal("val_a", p.environment.FROM_A)
        assert.are.equal("val_b", p.environment.FROM_B)
        assert.are.equal("from_a", p.environment.PRIORITY)
      end)

      it("presets without inheritance are unaffected", function()
        -- 'base' has no inherits; its own fields should remain intact.
        local p = find_preset(expanded.configure_presets, "base")
        assert.are.equal("Ninja", p.generator)
        assert.are.equal("base_val", p.environment.FROM_BASE)
      end)
    end)

    describe("build presets", function()
      it("child-build inherits environment from base-build", function()
        local p = find_preset(expanded.build_presets, "child-build")
        assert.are.equal("from_base_build", p.environment.BUILD_VAR)
      end)

      it("child-build has its own configure_preset", function()
        local p = find_preset(expanded.build_presets, "child-build")
        assert.are.equal("child", p.configure_preset)
      end)
    end)

    describe("test presets", function()
      it("child-test inherits environment from base-test", function()
        local p = find_preset(expanded.test_presets, "child-test")
        assert.are.equal("from_base_test", p.environment.TEST_VAR)
      end)
    end)
  end)

  describe("cross-file inheritance (CMakeUserPresets includes CMakePresets)", function()
    local expanded

    lazy_setup(function()
      expanded = load_expanded(fixture_dir("cross_file"), "CMakeUserPresets.json")
    end)

    it("user-preset inherits environment from shared-base in CMakePresets.json", function()
      local p = find_preset(expanded.configure_presets, "user-preset")
      assert.are.equal("shared_val", p.environment.FROM_SHARED)
    end)

    it("user-preset retains its own environment entries", function()
      local p = find_preset(expanded.configure_presets, "user-preset")
      assert.are.equal("user_val", p.environment.FROM_USER)
    end)

    it("user-preset inherits generator from shared-base", function()
      local p = find_preset(expanded.configure_presets, "user-preset")
      assert.are.equal("Ninja", p.generator)
    end)
  end)

  describe("cacheVariables inheritance merging", function()
    local expanded

    lazy_setup(function()
      expanded = load_expanded(fixture_dir("cache_variables_merge"))
    end)

    it("child inherits distinct cacheVariables entries from parent (union)", function()
      local p = find_preset(expanded.configure_presets, "child")
      assert.are.equal("base_value", p.cache_variables.BASE_VAR)
      assert.are.equal("child_value", p.cache_variables.CHILD_VAR)
    end)

    it("child keeps parent cacheVariables with the same key overridden", function()
      local p = find_preset(expanded.configure_presets, "overriding")
      assert.are.equal("overridden_overriding", p.cache_variables.SHARED_VAR)
      assert.are.equal("base_value", p.cache_variables.BASE_VAR)
    end)
  end)

  describe("macro expansion on inherited environment", function()
    local expanded

    lazy_setup(function()
      expanded = load_expanded(fixture_dir("macro_inheritance"))
    end)

    it("expands macros in environment entries inherited from a parent", function()
      local p = find_preset(expanded.configure_presets, "child")
      -- INHERITED_MACRO comes from 'base' and uses ${presetName}, which must
      -- expand to the child's own name after flattening.
      assert.are.equal("inherited_value_of_child", p.environment.INHERITED_MACRO)
      assert.is_nil(p.environment.INHERITED_MACRO:find("%${presetName}"))
    end)

    it("expands macros in environment entries defined on the child itself", function()
      local p = find_preset(expanded.configure_presets, "child")
      assert.are.equal("own_value_of_child", p.environment.OWN_MACRO)
      assert.is_nil(p.environment.OWN_MACRO:find("%${presetName}"))
    end)

    it("expands macros using the overridden (child-wins) value", function()
      local p = find_preset(expanded.configure_presets, "overriding")
      -- Child overrides INHERITED_MACRO; the merged (child) value is expanded.
      assert.are.equal("overridden_value_of_overriding", p.environment.INHERITED_MACRO)
      assert.is_nil(p.environment.INHERITED_MACRO:find("%${presetName}"))
    end)

    it("expands ${sourceDir} in inherited environment entries", function()
      local p = find_preset(expanded.configure_presets, "child")
      assert.is_not_nil(p.environment.SOURCE_DIR_BUILD)
      assert.is_nil(p.environment.SOURCE_DIR_BUILD:find("%${sourceDir}"))
    end)

    it("presets without inheritance are unaffected", function()
      local p = find_preset(expanded.configure_presets, "standalone")
      assert.are.equal("Unix Makefiles", p.generator)
      assert.are.equal("no_inheritance", p.environment.STANDALONE)
      assert.is_nil(p.inherits)
    end)
  end)
end)
