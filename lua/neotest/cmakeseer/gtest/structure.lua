local Suite = require("cmakeseer.gtest.json_report.testsuite")

---@private
---@class neotest.cmakeseer.gtest.structure.Suite
---@field suite neotest.Position
---@field tests any[]

local M = {}

--- The Neotest nested structure.
--- The first element at each level serves as the root for every following element.
--- So in a flat list, the first element is the root, and 2..n are nested under the root
--- This occurs for every recursive list in the structure.
---@alias neotest.cmakeseer.Structure
---| neotest.Position
---| (neotest.cmakeseer.Structure)[]

local function build_test_id(file, type_, test)
  return ("%s::%s::%s::%s"):format(file, type_, test.suite, test.name)
end

--- Builds the structure for an unknown test.
---@param file string The path to the file containing suites.
---@param test neotest.cmakeseer.gtest.treesitter.CapturedTest The treesitter captured test.
---@return neotest.cmakeseer.Structure position The position for the test
local function build_unknown_test_structure(file, test)
  local test_id = build_test_id(file, "unknown", test)
  ---@type neotest.Position
  local position = {
    id = test_id,
    type = "namespace",
    name = ("%s (RECOMPILE)"):format(test.name),
    path = file,
    range = test.range,
  }
  return position
end

--- Builds the structure for a basic test.
---@param file string The path to the file containing suites.
---@param test neotest.cmakeseer.gtest.treesitter.CapturedTest The treesitter captured test.
---@return neotest.cmakeseer.Structure position The positions for the test.
local function build_basic_test_structure(file, test)
  local test_id = build_test_id(file, "basic", test)
  ---@type neotest.Position
  local position = {
    id = test_id,
    type = "test",
    name = test.name,
    path = file,
    range = test.range,
  }
  return position
end

--- Builds the structure for a parameterized test.
---@param file string The path to the executable containing suites.
---@param suite cmakeseer.gtest.JsonReport.TestSuite.Parameterized The definition for the suite.
---@param test neotest.cmakeseer.gtest.treesitter.CapturedTest The treesitter capture test.
---@return neotest.cmakeseer.Structure position The position for the test.
local function build_parameterized_test_structure(file, suite, test)
  local test_id = build_test_id(file, "parameterized", test)
  ---@type neotest.cmakeseer.Structure
  local test_positions = {}
  for prefix, variants in pairs(suite.variants) do
    local variant_id = ("%s::%s"):format(test_id, prefix)
    ---@type neotest.Position[]
    local positions = {}
    for postfix, _ in pairs(variants) do
      local postfix_id = ("%s::%s"):format(variant_id, postfix)
      table.insert(
        positions,
        ---@type neotest.Position
        {
          id = postfix_id,
          type = "test",
          name = postfix,
          path = file,
          range = test.range,
        }
      )
    end
    table.sort(positions, function(a, b)
      return a.name < b.name
    end)

    table.insert(
      positions,
      1,
      ---@type neotest.Position
      {
        id = variant_id,
        type = "namespace",
        name = prefix,
        path = file,
        range = test.range,
      }
    )
    table.insert(test_positions, positions)
  end
  table.sort(test_positions, function(a, b)
    return a[1].name < b[1].name
  end)

  table.insert(
    test_positions,
    1,
    ---@type neotest.Position
    {
      id = test_id,
      type = "namespace",
      name = test.name,
      path = file,
      range = test.range,
    }
  )
  return test_positions
end

--- Builds the structure for a parameterized typed test suite.
---@param file string The path to the executable containing suites.
---@param suite cmakeseer.gtest.JsonReport.TestSuite.Typed The definition for the suite.
---@param test neotest.cmakeseer.gtest.treesitter.CapturedTest The treesitter capture test.
---@return neotest.cmakeseer.Structure position The position for the test.
local function build_typed_test_structure(file, suite, test)
  local test_id = build_test_id(file, "typed", test)
  ---@type neotest.cmakeseer.Structure
  local test_positions = {}
  for variant, _ in pairs(suite.variants) do
    local variant_id = ("%s::%s"):format(test_id, variant)
    table.insert(
      test_positions,
      ---@type neotest.Position
      {
        id = variant_id,
        type = "test",
        name = variant,
        path = file,
        range = test.range,
      }
    )
  end
  table.sort(test_positions, function(a, b)
    return a.name < b.name
  end)

  table.insert(
    test_positions,
    1,
    ---@type neotest.Position
    {
      id = test_id,
      type = "namespace",
      name = test.name,
      path = file,
      range = test.range,
    }
  )
  return test_positions
end

--- Builds the structure for a parameterized typed test suite.
---@param file string The path to the executable containing suites.
---@param suite cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped The definition for the suite.
---@param test neotest.cmakeseer.gtest.treesitter.CapturedTest The treesitter capture test.
---@return neotest.cmakeseer.Structure position The position for the test.
local function build_parameterized_typed_test_structure(file, suite, test)
  local test_id = build_test_id(file, "parameterized_typed", test)
  ---@type neotest.cmakeseer.Structure
  local test_positions = {}
  for prefix, variants in pairs(suite.variants) do
    local variant_id = ("%s::%s"):format(test_id, prefix)
    ---@type neotest.Position[]
    local positions = {}
    for postfix, _ in pairs(variants) do
      local postfix_id = ("%s::%s"):format(variant_id, postfix)
      table.insert(
        positions,
        ---@type neotest.Position
        {
          id = postfix_id,
          type = "test",
          name = postfix,
          path = file,
          range = test.range,
        }
      )
    end
    table.sort(positions, function(a, b)
      return a.name < b.name
    end)

    table.insert(
      positions,
      1,
      ---@type neotest.Position
      {
        id = variant_id,
        type = "namespace",
        name = prefix,
        path = file,
        range = test.range,
      }
    )
    table.insert(test_positions, positions)
  end
  table.sort(test_positions, function(a, b)
    return a[1].name < b[1].name
  end)

  table.insert(
    test_positions,
    1,
    ---@type neotest.Position
    {
      id = test_id,
      type = "namespace",
      name = test.name,
      path = file,
      range = test.range,
    }
  )
  return test_positions
end

--- Builds the structure tree for GTests.
---@param file string The absolute path to the file containing the tests.
---@param queried_tests table<string, neotest.cmakeseer.gtest.treesitter.CapturedTest[]> The queried tests for the entire executable, keyed by suite name.
---@param suites table<string, cmakeseer.gtest.JsonReport.TestSuite> The GTest suites associated with the file, keyed by name.
---@return any[] structure The recursive tree structure representing the tests.
function M.build(file, queried_tests, suites)
  -- Build all the test positions
  local all_suite_positions = {}
  for suite_name, tests in pairs(queried_tests) do
    assert(#tests > 0)
    table.sort(tests, function(a, b)
      return a.name < b.name
    end)

    local suite = suites[suite_name]
    local suite_range = { math.huge, math.huge, 0, 0 }
    ---@type neotest.Position[]
    local suite_positions = {}
    for _, test in ipairs(tests) do
      ---@type neotest.cmakeseer.Structure?
      local test_position
      if suite ~= nil and test.type == suite.type then
        -- We have additional data about the test
        if test.type == Suite.Type.Basic then
          ---@cast suite cmakeseer.gtest.JsonReport.TestSuite.Basic
          test_position = build_basic_test_structure(file, test)
        elseif test.type == Suite.Type.Parameterized then
          ---@cast suite cmakeseer.gtest.JsonReport.TestSuite.Parameterized
          test_position = build_parameterized_test_structure(file, suite, test)
        elseif test.type == Suite.Type.Typed then
          ---@cast suite cmakeseer.gtest.JsonReport.TestSuite.Typed
          test_position = build_typed_test_structure(file, suite, test)
        elseif test.type == Suite.Type.ParameterizedTyped then
          ---@cast suite cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped
          test_position = build_parameterized_typed_test_structure(file, suite, test)
        end
      else
        -- We don't have meta data-- just do what we can
        test_position = build_unknown_test_structure(file, test)
      end

      if test_position ~= nil then
        if test.range[1] < suite_range[1] then
          suite_range[1] = test.range[1]
        end
        if test.range[2] < suite_range[2] then
          suite_range[2] = test.range[2]
        end
        if test.range[3] > suite_range[3] then
          suite_range[3] = test.range[3]
        end
        if test.range[4] > suite_range[4] then
          suite_range[4] = test.range[4]
        end

        table.insert(suite_positions, test_position)
      end
    end

    local suite_type = suite and suite.type or "unknown"
    ---@type neotest.Position
    local suite_position = {
      id = ("%s::suite::%s::%s"):format(file, suite_type, suite_name),
      type = "namespace",
      name = suite_name,
      path = file,
      range = suite_range,
    }

    table.insert(all_suite_positions, {
      suite = suite_position,
      tests = suite_positions,
    })
  end

  table.sort(all_suite_positions, function(a, b)
    return a.suite.name < b.suite.name
  end)

  --  - Path-to-file (relative to the project root)
  --    - Prefix/Suite/Postfix; Might separate these later
  --      - Test/Postfix
  local structure = {
    ---@type neotest.Position
    {
      id = file,
      type = "file",
      name = vim.fn.fnamemodify(file, ":t:r"),
      path = file,
      -- TODO: Get the actual range
      range = { 0, 0, math.huge, math.huge },
    },
  }

  for _, suite_positions in ipairs(all_suite_positions) do
    local positions = suite_positions.tests
    table.insert(positions, 1, suite_positions.suite)
    table.insert(structure, positions)
  end

  return structure
end

return M
