local NeotestTypes = require("neotest.types")
local NeotestLib = require("neotest.lib")
local Cmakeseer = require("cmakeseer")

local TargetType = require("cmakeseer.cmake.api.codemodel.target").TargetType

---@private
---@class cmakeseer.neotest.gtest.Test
---@field file string
---@field line integer

---@type table<string, neotest.Result>
local g_test_results = {}

---@type table<string, string> Test files to executables.
local g_test_files = {}
---@type table<string, any> Set of test directories.
local g_test_dirs = {}
---@type table<string, table<string, table<string, cmakeseer.neotest.gtest.Test>>> Executables to suites, suites to tests.
local g_test_executables_suites = {}

---@private
---@class cmakeseer.neotest.gtest.TestCmd
---@field cmd vim.SystemObj
---@field cache string

---@private
local function __find_test_executables()
  g_test_files = {}
  g_test_dirs = {}
  g_test_executables_suites = {}

  local targets = vim.tbl_filter(function(value)
    return value.type == TargetType.Executable and string.match(value.name, "[tT]est")
  end, Cmakeseer.get_targets())

  ---@type table<string, cmakeseer.neotest.gtest.TestCmd>
  local executable_test_cmds = {}
  for _, target in ipairs(targets) do
    assert(target.artifacts ~= nil, "Artifacts for executable should not have been nil")
    assert(#target.artifacts == 1, "Should only have one artifact for executable")

    local executable = vim.fs.joinpath(Cmakeseer.get_build_directory(), target.artifacts[1].path)
    local cache = vim.fs.joinpath(
      Cmakeseer.get_build_directory(),
      string.format("cmakeseer_gtest_cache_%s.json", target.artifacts[1].path)
    )
    local success, test_cmd = pcall(vim.system, {
      executable,
      "--gtest_list_tests",
      string.format("--gtest_output=json:%s", cache),
    }, { timeout = 10 })
    if not success then
      goto continue
    end

    executable_test_cmds[executable] = { cmd = test_cmd, cache = cache }
    ::continue::
  end

  for executable, data in pairs(executable_test_cmds) do
    data.cmd:wait(10)
    if vim.fn.filereadable(data.cache) == 0 then
      goto continue
    end

    ---@type {string: {string: cmakeseer.neotest.gtest.Test}}
    local suites = {}
    local test_data = vim.json.decode(io.open(data.cache, "r"):read("*a"))
    for _, suite in ipairs(test_data.testsuites) do
      ---@type {string: cmakeseer.neotest.gtest.Test}
      local tests = {}
      for _, test in ipairs(suite.testsuite) do
        tests[test.name] = {
          file = test.file,
          line = test.line,
        }

        g_test_files[test.file] = executable
      end

      suites[suite.name] = tests
    end

    g_test_executables_suites[executable] = suites
    ::continue::
  end

  -- TODO: Almost all CWD calls actually probably need to be the project root instead. . .
  local cwd = vim.fn.getcwd()
  g_test_dirs[cwd] = true
  for file, _ in pairs(g_test_files) do
    local path = vim.fn.fnamemodify(file, ":h")
    if path:sub(1, #cwd) ~= cwd then
      vim.notify(string.format("Path `%s` is not in cwd; skipping tests", path), vim.log.levels.WARN)
      goto continue
    end

    while #path > #cwd do
      g_test_dirs[path] = true
      path = vim.fn.fnamemodify(path, ":h")
    end
    ::continue::
  end
end

---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter
local M = {
  name = "CMakeSeer GTest",
}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.root(cwd)
  __find_test_executables()
  return cwd
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param project_root string Root directory of project
---@return boolean
function M.filter_dir(name, rel_path, project_root)
  _ = name
  local path = vim.fs.joinpath(project_root, rel_path)
  return g_test_dirs[path] ~= nil
end

---@async
---@param file_path string
---@return boolean
function M.is_test_file(file_path)
  return g_test_files[file_path] ~= nil
end

---@class cmakeseer.neotest.gtest.Position
---@field file_position neotest.Position
---@field suites table<string, neotest.Position[]>

---@private
--- Treesitter query to extract GTest tests.
local G_GTEST_QUERY = [[
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

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local executable = g_test_files[file_path]
  assert(executable ~= nil)

  -- queried_tests has the form { file_position, { test_position }, { test_position }, ... }
  local queried_tests = require("neotest.lib").treesitter.parse_positions(file_path, G_GTEST_QUERY, nil):to_list() ---@diagnostic disable-line:param-type-mismatch
  ---@type cmakeseer.neotest.gtest.Position
  local gtest_positions = {
    file_position = queried_tests[1],
    suites = {},
  }
  table.remove(queried_tests, 1)
  ---@cast queried_tests neotest.Position[][]

  local suites = g_test_executables_suites[executable]
  for suite_name, tests in pairs(suites) do
    ---@type neotest.Position[]
    local suite_positions = {}
    for test_name, test in pairs(tests) do
      assert(test.file == file_path)

      -- Find the test position from the query results for this test
      local position = nil
      for i, pos in ipairs(queried_tests) do
        pos = pos[1]
        if pos.name == test_name then
          if pos.range[1] == test.line - 1 then
            assert(pos.type == "test")
            position = table.remove(queried_tests, i)[1]
            break
          end
        end
      end

      if position == nil then
        vim.notify(string.format("Failed to find position for GTest %s::%s::%s", file_path, suite_name, test_name))
      else
        position.suite = suite_name
        table.insert(suite_positions, position)
      end
    end

    table.sort(suite_positions, function(a, b)
      return a.range[1] < b.range[1]
    end)
    gtest_positions.suites[suite_name] = suite_positions
  end

  ---@type neotest.Position[] Create the list of positions from which we will build the tree
  local flat_tree = { gtest_positions.file_position }

  -- Build the suite tests
  for suite, positions in pairs(gtest_positions.suites) do
    local suite_min_line = positions[1].range[1]
    local suite_min_col = positions[1].range[2]
    local suite_max_line = positions[#positions].range[3]
    local suite_max_col = positions[#positions].range[4]

    ---@type neotest.Position
    local suite_position = {
      id = string.format("%s::%s", executable, suite),
      type = "namespace",
      name = suite,
      path = file_path,
      range = { suite_min_line, suite_min_col, suite_max_line, suite_max_col },
    }
    table.insert(flat_tree, suite_position)
    vim.list_extend(flat_tree, positions)
  end

  local tree = NeotestLib.positions.parse_tree(flat_tree, {
    nested_tests = false,
    require_namespaces = true,
    position_id = function(position, _)
      if position.type == "file" then
        return position.path
      elseif position.type == "namespace" then
        return string.format("%s::%s", position.path, position.name)
      elseif position.type == "test" then
        ---@diagnostic disable:undefined-field We smuggled in a `suite` field
        assert(position.suite ~= nil)
        return string.format("%s::%s::%s", position.path, position.suite, position.name)
        ---@diagnostic enable:undefined-field
      end

      error("Unreachable")
    end,
  })
  return tree
end

---@class cmakeseer.neotest.gtest.TestId
---@field neotest_id string
---@field file string
---@field suite string?
---@field test string?

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  local raw_id = args[1]
  local id_parts = vim.fn.split(raw_id, "::")
  local executable = g_test_files[id_parts[1]]
  if executable == nil then
    vim.notify(string.format("No executable for test ID `%s`", raw_id), vim.log.levels.ERROR)
    return nil
  end

  ---@type cmakeseer.neotest.gtest.TestId
  local id = {
    neotest_id = raw_id,
    file = id_parts[1],
    suite = id_parts[2],
    test = id_parts[3],
  }

  local spec = nil
  if #id_parts == 1 then
    -- This is a file
    local suites = {}
    for _, suite_tests in pairs(g_test_executables_suites) do
      for suite, _ in pairs(suite_tests) do
        table.insert(suites, suite)
      end
    end
    local suite_str = table.concat(suites, ".*:")
    spec = {
      command = { executable, string.format("--gtest_filter=%s.*", suite_str) },
      context = {
        executable = executable,
        id = id,
      },
    }
  elseif #id_parts == 2 then
    -- This is a suite
    spec = {
      command = { executable, string.format("--gtest_filter=%s.*", id.suite) },
      context = {
        executable = executable,
        id = id,
      },
    }
  elseif #id_parts == 3 then
    -- This is an individual test
    spec = {
      command = { executable, string.format("--gtest_filter=%s.%s", id.suite, id.test) },
      context = {
        executable = executable,
        id = id,
      },
    }
  else
    vim.notify(string.format("Unrecognized test ID: `%s`", raw_id), vim.log.levels.ERROR)
  end
  return spec
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, result, _) end

--- Sets up the adapter.
---@return neotest.Adapter adapter The adapter.
function M.setup()
  return M
end

return M
