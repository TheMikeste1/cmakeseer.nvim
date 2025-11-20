local Suite = require("cmakeseer.neotest.gtest.suite")

---@private
---@class cmakeseer.neotest.gtest.structure.Suite
---@field suite neotest.Position
---@field tests any[]

local M = {}

--- Builds the structure for a basic test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition cmakeseer.neotest.gtest.suite.Basic The definition for the Suite.
---@param tests cmakeseer.neotest.gtest.treesitter.CapturedTest[] The treesitter tests for the suite.
---@return cmakeseer.neotest.gtest.structure.Suite[] positions The positions for the suite and its tests.
local function build_basic_suite_structure(executable, suite_definition, tests)
  local suite_id = string.format("%s::%s", executable, suite_definition.name)
  local positions = {}
  for _, test in ipairs(tests) do
    local test_is_recogized = suite_definition.tests[test.name] ~= nil
    if not test_is_recogized then
      goto continue
    end

    local position = {
      id = string.format("%s::%s", suite_id, test.name),
      type = "test",
      name = test.name,
      path = test.filepath,
      range = test.range,
    }
    table.insert(positions, { position })
    ::continue::
  end

  ---@type neotest.Position
  local suite_position = {
    id = suite_id,
    type = "namespace",
    name = suite_definition.name,
    path = positions[1][1].path,
    range = positions[1][1].range,
  }

  return { {
    suite = suite_position,
    tests = positions,
  } }
end

--- Builds the structure for a parameterized test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition cmakeseer.neotest.gtest.suite.Parameterized The definition for the suite.
---@param tests cmakeseer.neotest.gtest.treesitter.CapturedTest[] The treesitter tests for the suite.
---@return cmakeseer.neotest.gtest.structure.Suite[] positions The positions for the suite and its tests.
local function build_parameterized_suite_structure(executable, suite_definition, tests)
  local suite_structures = {}
  for prefix, params in pairs(suite_definition.value_parameters) do
    local suite_name = string.format("%s/%s", prefix, suite_definition.name)
    local suite_id = string.format("%s::%s", executable, suite_name)
    local positions = {}
    for _, test in ipairs(tests) do
      local test_is_recogized = suite_definition.tests[test.name] ~= nil
      if not test_is_recogized then
        goto continue
      end

      local test_id = string.format("%s::%s", suite_id, test.name)
      local test_positions = {
        {
          id = test_id,
          type = "dir",
          name = test.name,
          path = test.filepath,
          range = test.range,
        },
      }

      for i, param in ipairs(params) do
        ---@type neotest.Position
        local position = {
          id = string.format("%s/%d", test_id, i - 1),
          type = "file",
          name = param,
          path = test.filepath,
          range = test.range,
        }
        table.insert(test_positions, { position })
      end

      table.insert(positions, test_positions)
      ::continue::
    end

    ---@type neotest.Position
    local suite_position = {
      id = suite_id,
      type = "namespace",
      name = suite_name,
      path = positions[1][1].path,
      range = positions[1][1].range,
    }

    table.insert(suite_structures, {
      suite = suite_position,
      tests = positions,
    })
  end
  return suite_structures
end

--- Builds the structure for a typed test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition cmakeseer.neotest.gtest.suite.ParameterizedTyped The definition for the suite.
---@param tests cmakeseer.neotest.gtest.treesitter.CapturedTest[] The treesitter tests for the suite.
---@return cmakeseer.neotest.gtest.structure.Suite[] positions The positions for the suite and its tests.
local function build_parameterized_typed_suite_structure(executable, suite_definition, tests)
  local suite_structures = {}
  for prefix, type_parameters in pairs(suite_definition.parameterized_type_parameters) do
    local suite_id = string.format("%s::%s/%s", executable, prefix, suite_definition.name)
    local suite_positions = {}
    for i, type_param in ipairs(type_parameters) do
      local postfix_id = string.format("%s/%d", suite_id, i - 1)
      local positions = {}
      for _, test in ipairs(tests) do
        local test_is_recogized = suite_definition.tests[test.name] ~= nil
        if not test_is_recogized then
          goto continue
        end

        local test_id = string.format("%s::%s", postfix_id, test.name)
        local position = {
          id = test_id,
          type = "test",
          name = test.name,
          path = test.filepath,
          range = test.range,
        }

        table.insert(positions, { position })
        ::continue::
      end

      local postfix_position = {
        id = postfix_id,
        type = "dir",
        name = type_param,
        path = positions[1][1].path,
        range = positions[1][1].range,
      }

      table.insert(positions, 1, postfix_position)
      table.insert(suite_positions, positions)
    end

    ---@type neotest.Position
    local suite_position = {
      id = suite_id,
      type = "namespace",
      name = string.format("%s/%s", prefix, suite_definition.name),
      path = suite_positions[1][1].path,
      range = suite_positions[1][1].range,
    }
    table.insert(suite_structures, {
      suite = suite_position,
      tests = suite_positions,
    })
  end

  return suite_structures
end

--- Builds the structure for a parameterized typed test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition cmakeseer.neotest.gtest.suite.Typed The definition for the suite.
---@param tests cmakeseer.neotest.gtest.treesitter.CapturedTest[] The treesitter tests for the suite.
---@return cmakeseer.neotest.gtest.structure.Suite[] positions The positions for the suite and its tests.
local function build_typed_suite_structure(executable, suite_definition, tests)
  local suite_id = string.format("%s::%s", executable, suite_definition.name)
  local all_positions = {}
  for i, type_param in ipairs(suite_definition.type_parameters) do
    local postfix_id = string.format("%s/%d", suite_id, i - 1)
    local positions = {}
    for _, test in ipairs(tests) do
      local test_is_recogized = suite_definition.tests[test.name] ~= nil
      if not test_is_recogized then
        goto continue
      end

      local test_id = string.format("%s::%s", postfix_id, test.name)
      local position = {
        id = test_id,
        type = "test",
        name = test.name,
        path = test.filepath,
        range = test.range,
      }

      table.insert(positions, { position })
      ::continue::
    end

    local postfix_position = {
      id = postfix_id,
      type = "dir",
      name = type_param,
      path = positions[1][1].path,
      range = positions[1][1].range,
    }

    table.insert(positions, 1, postfix_position)
    table.insert(all_positions, positions)
  end
  ---@type neotest.Position
  local suite_position = {
    id = suite_id,
    type = "namespace",
    name = suite_definition.name,
    path = all_positions[1][1].path,
    range = all_positions[1][1].range,
  }

  return { {
    suite = suite_position,
    tests = all_positions,
  } }
end

--- Builds the structure tree for GTests.
---@param executable string The path to the executable containing the tests.
---@param queried_tests table<string, cmakeseer.neotest.gtest.treesitter.CapturedTest[]> The queried tests for the entire executable.
---@return any[] structure The recursive tree structure representing the tests.
function M.build(executable, queried_tests, suites)
  --  - Executable
  --    - Prefix/Suite/Postfix; Might separate these later
  --      - Test/Postfix
  local structure = {
    ---@type neotest.Position
    {
      id = executable,
      type = "file",
      name = vim.fn.fnamemodify(executable, ":t:r"),
      path = executable,
      range = { 0, 0, 0, 0 },
    },
  }

  local all_suite_positions = {}
  for suite_name, tests in pairs(queried_tests) do
    local suite_definition = suites[suite_name]
    if suite_definition == nil then
      -- We don't know about this suite yet
      -- We could probably do something with it though. . .
      goto continue
    end

    local suite_type = Suite.type_from_suite(suite_definition)
    local suite_positions = {}
    if suite_type == "Suite" then
      suite_positions = build_basic_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "ParameterizedSuite" then
      ---@cast suite_definition cmakeseer.neotest.gtest.suite.Parameterized
      suite_positions = build_parameterized_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "TypedSuite" then
      ---@cast suite_definition cmakeseer.neotest.gtest.suite.Typed
      suite_positions = build_typed_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "ParameterizedTypedSuite" then
      ---@cast suite_definition cmakeseer.neotest.gtest.suite.ParameterizedTyped
      suite_positions = build_parameterized_typed_suite_structure(executable, suite_definition, tests)
    else
      vim.notify_once("Unrecognized suite type for suite " .. suite_name, vim.log.levels.DEBUG)
      goto continue
    end

    vim.list_extend(all_suite_positions, suite_positions)
    ::continue::
  end

  table.sort(all_suite_positions, function(a, b)
    return a.suite.name < b.suite.name
  end)

  for _, positions in ipairs(all_suite_positions) do
    local position = positions.tests
    table.insert(position, 1, positions.suite)
    table.insert(structure, position)
  end

  return structure
end

return M
