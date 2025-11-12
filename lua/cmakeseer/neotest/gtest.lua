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

---@type table<string, string>
local g_test_files = {}
---@type table<string, table<string, table<string, cmakeseer.neotest.gtest.Test>>>
local g_test_executables_suites = {}

---@private
local function __find_test_executables()
  g_test_files = {}
  g_test_executables_suites = {}

  local targets = vim.tbl_filter(function(value)
    return value.type == TargetType.Executable
  end, Cmakeseer.get_targets())

  ---@type table<string, any>
  local executable_test_cmds = {}
  for _, target in ipairs(targets) do
    assert(target.artifacts ~= nil, "Artifacts for executable should not have been nil")
    assert(#target.artifacts == 1, "Should only have one artifact for executable")

    local executable = vim.fs.joinpath(Cmakeseer.get_build_directory(), target.artifacts[1].path)
    local cache = vim.fs.joinpath(
      Cmakeseer.get_build_directory(),
      string.format("cmakeseer_gtest_cache_%s.json", target.artifacts[1].path)
    )
    local test_cmd = vim.system({
      executable,
      "--gtest_list_tests",
      string.format("--gtest_output=json:%s", cache),
    }, { timeout = 10 })
    executable_test_cmds[executable] = { cmd = test_cmd, cache = cache }
  end

  for executable, data in pairs(executable_test_cmds) do
    data.cmd:wait()
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
end

---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter

---@type cmakeseer.GTestAdapter
---@diagnostic disable-next-line: missing-fields
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
  return name ~= "__cmake_systeminformation"
    and vim.fs.joinpath(project_root, rel_path) ~= Cmakeseer.get_build_directory()
end

---@async
---@param file_path string
---@return boolean
function M.is_test_file(file_path)
  return g_test_files[file_path] ~= nil
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local executable = g_test_files[file_path]
  assert(executable ~= nil)
  local suites = g_test_executables_suites[executable]

  ---@type neotest.Position[]
  local positions = {}
  ---@type {string: neotest.Position}
  local file_positions = {}
  for suite_name, tests in pairs(suites) do
    for test_name, test in pairs(tests) do
      ---@type neotest.Position
      local position = {
        id = string.format("%s::%s::%s", executable, suite_name, test_name),
        type = "test",
        name = test_name,
        path = test.file,
        range = { test.line, 0, test.line, 999 },
      }
      table.insert(positions, position)

      local relative_path = test.file:sub(#vim.fn.getcwd() + 2)
      ---@type neotest.Position[]
      file_positions[test.file] = {
        id = test.file,
        type = "file",
        path = test.file,
        name = relative_path,
        range = { 0, 0, 99999, 99999 }, -- TSNode:range
      }
    end
  end
  table.sort(positions, function(a, b)
    return a.id < b.id
  end)
  for _, pos in pairs(file_positions) do
    table.insert(positions, pos)
  end
  print("POS " .. vim.inspect(positions))

  local tree = NeotestLib.positions.parse_tree(positions, { nested_tests = true })
  print("TREE: " .. vim.inspect(tree))
  return tree
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  print("SPEC")
  -- local id = args[1]
  -- local id_parts = vim.fn.split(id, "::")
  -- if #id_parts == 1 then
  --   if M.__options.parallel_instances then
  --     return __get_file_test_run_specs(id)
  --   else
  --     return __get_file_test_run_spec(id)
  --   end
  -- end
  --
  -- local test_name = table.concat(id_parts, "::", 2)
  -- return __get_test_run_spec_by_id(id, test_name)
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
