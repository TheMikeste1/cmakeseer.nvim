---@class neotest.cmakeseer.gtest.treesitter.CapturedTest
---@field name string The name of the test.
---@field type "TEST"|"TEST_F"|"TEST_P"|"TYPED_TEST"|"TYPED_TEST_P" The type of the test.
---@field suite string The suite to which the test belongs.
---@field range [integer, integer, integer, integer] The range of the test.

---@class neotest.cmakeseer.gtest.treesitter.CapturedFileTest: neotest.cmakeseer.gtest.treesitter.CapturedTest
---@field filepath string The path to the file containing the test.

---@private
--- Treesitter query to extract GTest tests.
local GTEST_QUERY = [[
(call_expression
  (identifier) @p_suite.type (#any-of? @p_suite.type "INSTANTIATE_TEST_SUITE_P" "INSTANTIATE_TYPED_TEST_SUITE_P")
  (argument_list
    (identifier) @p_suite.prefix
    (identifier) @p_suite.name
  )
)

(function_definition
  declarator: (function_declarator
    declarator: (identifier) @test.type (#any-of? @test.type "TEST" "TEST_F" "TEST_P" "TYPED_TEST" "TYPED_TEST_P")
    parameters: (parameter_list
      (parameter_declaration
        type: (type_identifier) @test.suite
      )
      (parameter_declaration
        type: (type_identifier) @test.name
      )
    )
  )
) @test.definition
]]
local LANG = "cpp"
local parse_query = vim.treesitter.query.parse or vim.treesitter.parse_query

--- @description Extracts structured node information from matches and captures returned by the treesitter query matching process.
--- @param matches table<integer, TSNode[]> The array of successful match nodes.
--- @param captures string[] The array of capture groups defined in the query.
--- @return table<string, table<string, TSNode>> captured_nodes The captured nodes, keyed by capture type, where each value is a table of nodes found for that type.
local function extract_nodes(matches, captures)
  local captured_nodes = {}
  for i, capture in ipairs(captures) do
    local match = matches[i]
    if match ~= nil then
      local capture_parts = vim.split(capture, ".", { plain = true })
      assert(#capture_parts == 2, "Each capture should have exactly two parts")
      local type = capture_parts[1]
      local field = capture_parts[2]
      captured_nodes[type] = captured_nodes[type] or {}
      if #match > 1 then
        vim.notify("#match > 1, let the plugin author know!")
      end
      captured_nodes[type][field] = match[1] or match
    end
  end

  return captured_nodes
end

---@param test table<string, TSNode> The captured nodes containing 'name', 'type', 'suite', and 'definition'.
---@param test_string string The source text used for parsing, required to extract node content.
---@return neotest.cmakeseer.gtest.treesitter.CapturedTest captured_test The fully constructed test object.
local function build_captured_test(test, test_string)
  local name = vim.treesitter.get_node_text(test["name"], test_string)
  local type = vim.treesitter.get_node_text(test["type"], test_string)
  local suite = vim.treesitter.get_node_text(test["suite"], test_string)
  local definition = test["definition"]
  return {
    name = name,
    type = type,
    suite = suite,
    range = { definition:range() },
  }
end

local M = {}

--- Queries for tests in a string.
---@param test_string string The string to parse.
---@return table<string, neotest.cmakeseer.gtest.treesitter.CapturedTest[]>|string maybe_tests The queried tests, if the query succeeded. Otherwise, a string with describing why the query failed.
function M.query_tests_from_string(test_string)
  if test_string == nil then
    return {}
  end

  local parser = vim.treesitter.get_string_parser(test_string, LANG, { injections = { [LANG] = "" } })
  local trees = parser:parse()
  if trees == nil or #trees < 1 then
    return "Failed to parse"
  end

  -- There should only ever be one tree since there's only one language
  if #trees > 1 then
    vim.notify("Somehow got more than one tree. Let the plugin author know!")
  end

  local root = trees[1]:root()
  local query = parse_query(LANG, GTEST_QUERY)

  local ts_tests = {}
  for _, matches, _, _ in query:iter_matches(root, test_string, nil, nil, { all = false }) do
    local captured_nodes = extract_nodes(matches, query.captures)
    if captured_nodes["test"] ~= nil then
      local test = captured_nodes["test"]
      local ts_test = build_captured_test(test, test_string)
      local suite = ts_test.suite

      ts_tests[suite] = ts_tests[suite] or {}
      table.insert(ts_tests[suite], ts_test)
    end
  end

  return ts_tests
end

--- Queries for tests in a file.
---@param filepath string The path to the file.
---@return table<string, neotest.cmakeseer.gtest.treesitter.CapturedFileTest[]>|string maybe_tests The queried tests, if the query succeeded. Otherwise, a string with describing why the query failed.
function M.query_tests(filepath)
  local file = io.open(filepath, "r")
  if file == nil then
    return "Could not open " .. filepath
  end

  ---@type string
  local contents = file:read("*a")
  file:close()

  local maybe_test_suites = M.query_tests_from_string(contents)
  if type(maybe_test_suites) ~= "string" then
    for _, tests in pairs(maybe_test_suites) do
      for _, test in ipairs(tests) do
        ---@cast test neotest.cmakeseer.gtest.treesitter.CapturedFileTest
        test.filepath = filepath
      end
    end
    ---@cast maybe_test_suites table<string, neotest.cmakeseer.gtest.treesitter.CapturedFileTest[]>
  end

  return maybe_test_suites
end

return M
