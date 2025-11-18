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
---@return cmakeseer.neotest.gtest.Positions|string positions The positions for the tests in a file.
function M.query_tests(filepath)
  -- Based off neotest.lib.treesitter._parse_positions
  local lang = "cpp"
  local parse_query = vim.treesitter.query.parse or vim.treesitter.parse_query
  local query = parse_query(lang, GTEST_QUERY)

  local file = io.open(filepath, "r")
  if file == nil then
    return "Could not open " .. filepath
  end

  local contents = file:read("*a")
  file:close()

  local suite_prefixes = {}
  ---@type table <string, neotest.Position[]>
  local suite_test_positions = {}
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

    assert(captured_nodes["test"] or captured_nodes["p_suite"], "Neither test nor p_suite was found")
    assert(not (captured_nodes["test"] and captured_nodes["p_suite"]), "p_suite and test found. They must be exclusive")

    if captured_nodes["test"] ~= nil then
      local test = captured_nodes["test"]
      ---@type string
      local name = vim.treesitter.get_node_text(test["name"], contents)
      local suite = vim.treesitter.get_node_text(test["suite"], contents)
      local definition = test["definition"]
      ---@type neotest.Position
      local pos = {
        id = nil,
        type = "test",
        path = filepath,
        name = name,
        range = { definition:range() },
      }

      suite_test_positions[suite] = suite_test_positions[suite] or {}
      table.insert(suite_test_positions[suite], pos)
    elseif captured_nodes["suite"] ~= nil then
      local suite = captured_nodes["suite"]
      local name = vim.treesitter.get_node_text(suite["name"], contents)
      local prefix = vim.treesitter.get_node_text(suite["prefix"], contents)
      suite_prefixes[name] = suite_prefixes[name] or {}
      table.insert(suite_prefixes[name], prefix)
    end
  end

  ---@type cmakeseer.neotest.gtest.Positions
  local all_positions = {
    file_position = {
      id = filepath,
      type = "file",
      path = filepath,
      name = vim.fs.basename(filepath),
      range = { root:range() },
    },
    suites = {},
  }

  -- Build the suite tests
  for suite, positions in pairs(suite_test_positions) do
    if #positions == 0 then
      goto continue
    end

    table.sort(positions, function(a, b)
      return a.range[1] < b.range[1]
    end)

    local suite_min_line = positions[1].range[1]
    local suite_min_col = positions[1].range[2]
    local suite_max_line = positions[#positions].range[3]
    local suite_max_col = positions[#positions].range[4]

    ---@type cmakeseer.neotest.gtest.SuitePosition
    all_positions.suites[suite] = {
      suite = {
        prefixes = suite_prefixes[suite] or {},
        position = {
          id = nil,
          type = "namespace",
          name = suite,
          path = filepath,
          range = { suite_min_line, suite_min_col, suite_max_line, suite_max_col },
        },
      },
      tests = positions,
    }
    ::continue::
  end

  return all_positions
end

return M
