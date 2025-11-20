---@class cmakeseer.neotest.gtest.treesitter.CapturedTest
---@field name string The name of the test.
---@field type "TEST"|"TEST_F"|"TEST_P"|"TYPED_TEST"|"TYPED_TEST_P" The type of the test.
---@field suite string The suite to which the test belongs.
---@field filepath string The path to the file containing the test.
---@field range [integer, integer, integer, integer] The range of the test.

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

local M = {}

--- Queries for tests in a file.
---@param filepath string The path to the file.
---@return table<string, cmakeseer.neotest.gtest.treesitter.CapturedTest[]>|string maybe_tests The queried tests, if the query succeeded. Otherwise, a string with describing why the query failed.
function M.query_tests(filepath)
  local lang = "cpp"
  local parse_query = vim.treesitter.query.parse or vim.treesitter.parse_query
  local query = parse_query(lang, GTEST_QUERY)

  local file = io.open(filepath, "r")
  if file == nil then
    return "Could not open " .. filepath
  end

  local contents = file:read("*a")
  file:close()

  local ts_tests = {}
  local lang_tree = vim.treesitter.get_string_parser(contents, lang, { injections = { [lang] = "" } })
  local root = lang_tree:parse()[1]:root()
  for _, matches, _, _ in query:iter_matches(root, contents, nil, nil, { all = false }) do
    local captured_nodes = {}
    for i, capture in ipairs(query.captures) do
      local capture_parts = vim.split(capture, "%.")
      assert(#capture_parts == 2, "Each capture should have exactly two parts")
      local type = capture_parts[1]
      local field = capture_parts[2]
      local match = matches[i]
      if match ~= nil then
        captured_nodes[type] = captured_nodes[type] or {}
        captured_nodes[type][field] = match
      end
    end

    if captured_nodes["test"] == nil then
      -- We're not doing anything with the suite capture. Yet.
      goto continue
    end

    local test = captured_nodes["test"]
    local name = vim.treesitter.get_node_text(test["name"], contents)
    local type = vim.treesitter.get_node_text(test["type"], contents)
    local suite = vim.treesitter.get_node_text(test["suite"], contents)
    local definition = test["definition"]
    ---@type cmakeseer.neotest.gtest.treesitter.CapturedTest
    local ts_test = {
      name = name,
      type = type,
      suite = suite,
      filepath = filepath,
      range = { definition:range() },
    }

    ts_tests[suite] = ts_tests[suite] or {}
    table.insert(ts_tests[suite], ts_test)
    ::continue::
  end

  return ts_tests
end

return M
