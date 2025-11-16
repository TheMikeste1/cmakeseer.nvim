---@private
--- Treesitter query to extract GTest tests.
local GTEST_QUERY = [[
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

  ---@type table <string, neotest.Position[]>
  local suite_test_positions = {}
  local lang_tree = vim.treesitter.get_string_parser(contents, lang, { injections = { [lang] = "" } })
  local root = lang_tree:parse()[1]:root()
  for _, match, _, _ in query:iter_matches(root, contents, nil, nil, { all = false }) do
    local captured_nodes = {}
    for i, capture in ipairs(query.captures) do
      captured_nodes[capture] = match[i]
    end

    ---@type string
    local name = vim.treesitter.get_node_text(captured_nodes["test.name"], contents)
    local definition = captured_nodes["test.definition"]
    local suite = vim.treesitter.get_node_text(captured_nodes["test.suite"], contents)
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
        id = nil,
        type = "namespace",
        name = suite,
        path = filepath,
        range = { suite_min_line, suite_min_col, suite_max_line, suite_max_col },
      },
      tests = positions,
    }
    ::continue::
  end

  return all_positions
end

return M
