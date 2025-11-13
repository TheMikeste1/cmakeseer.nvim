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
---@type table<string, any>
local g_test_dirs = {}
---@type table<string, table<string, table<string, cmakeseer.neotest.gtest.Test>>>
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

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local executable = g_test_files[file_path]
  assert(executable ~= nil)
  local suites = g_test_executables_suites[executable]

  local relative_path = vim.fn.fnamemodify(file_path, ":.")
  ---@type cmakeseer.neotest.gtest.Position
  local gtest_positions = {
    file_position = {
      id = file_path,
      type = "file",
      path = file_path,
      name = relative_path,
      range = { 0, 0, 0, 0 }, -- TSNode:range
    },
    suites = {},
  }

  for suite_name, tests in pairs(suites) do
    ---@type neotest.Position[]
    local suite_positions = {}
    for test_name, test in pairs(tests) do
      assert(test.file == file_path)

      ---@type neotest.Position
      local position = {
        id = string.format("%s::%s::%s", executable, suite_name, test_name),
        type = "test",
        name = test_name,
        path = file_path,
        -- TODO: Use actual test end line
        range = { test.line - 1, 0, test.line, math.huge },
      }
      table.insert(suite_positions, position)
    end

    table.sort(suite_positions, function(a, b)
      return a.range[1] < b.range[1]
    end)
    gtest_positions.suites[suite_name] = suite_positions
  end

  --- Sorted positions to be converted to a tree
  local min_line = math.huge
  local max_line = 0
  ---@type neotest.Position[]
  local flat_tree = { gtest_positions.file_position }
  for suite, positions in pairs(gtest_positions.suites) do
    local suite_min_line = positions[1].range[1]
    local suite_max_line = positions[#positions].range[3]

    if suite_min_line < min_line then
      min_line = suite_min_line
    end
    if suite_max_line > max_line then
      max_line = suite_max_line
    end

    ---@type neotest.Position
    local suite_position = {
      id = string.format("%s::%s", executable, suite),
      type = "namespace",
      name = suite,
      path = file_path,
      range = { suite_min_line, 0, suite_max_line, math.huge },
    }
    table.insert(flat_tree, suite_position)
    vim.list_extend(flat_tree, positions)
  end

  flat_tree[1].range[1] = min_line
  flat_tree[1].range[3] = max_line

  local tree = NeotestLib.positions.parse_tree(flat_tree, { nested_tests = true, require_namespaces = true })
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
