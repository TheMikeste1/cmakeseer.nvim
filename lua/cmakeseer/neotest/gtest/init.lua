local Cmakeseer = require("cmakeseer")
local TargetType = require("cmakeseer.cmake.api.codemodel.target").TargetType

---@private
---@class cmakeseer.neotest.gtest.Context
---@field executable string
---@field neotest_id string
---@field id cmakeseer.neotest.gtest.TestId
---@field output_file string

---@private
---@class cmakeseer.neotest.gtest.TestId
---@field executable string
---@field suite string?
---@field test string?

---@type table<string, table<string>> Executables to test files.
local g_executable_files = {}
---@type table<string> Set of test directories.
local g_test_dirs = {}
---@type table<string, table<string, table<cmakeseer.neotest.gtest.suite.Type, cmakeseer.neotest.gtest.suite.Basic>>> Executables to suite names to Suites.
local g_test_executables_suites = {}

-- TODO: Have the plugin subscribe to build events
local M
---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter
M = {
  name = "CMakeSeer GTest",
  opts = {
    --- Filter out targets when looking for tests.
    ---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
    ---@return boolean keep If the target should be kept.
    target_filter = function(target)
      return string.match(target.name, "[tT]est") and not M.is_gtest_test(target)
    end,
    cache_directory = function()
      return vim.fs.joinpath(Cmakeseer.get_build_directory(), ".cache", "cmakeseer", "gtest")
    end,
  },
  treesitter = require("cmakeseer.neotest.gtest.treesitter"),
}

--- Compares the times of two stat times.
---@param a { nsec: integer, sec: integer }
---@param b { nsec: integer, sec: integer }
---@return integer 1 if a is greater, -1 if a is lesser, 0 if equal
local function compares_times(a, b)
  if a.sec > b.sec then
    return 1
  end
  if a.sec < b.sec then
    return -1
  end

  if a.nsec > b.nsec then
    return 1
  end
  if a.nsec < b.nsec then
    return -1
  end
  return 0
end

--- Generates all the test commands to check if an executable is a GTest executable.
---@param targets cmakeseer.cmake.api.codemodel.Target[] The targets to check.
---@return table<string, {cmd: vim.SystemObj?, cache: string}> test_cmds The executable paired with the commands to check each target.
local function generate_executable_commands(targets)
  local test_cmds = {}
  for _, target in ipairs(targets) do
    assert(target.type == TargetType.Executable, "Only executable targets are supported")
    assert(target.artifacts ~= nil, "Artifacts for executable should not have been nil")
    assert(#target.artifacts == 1, "Should only have one artifact for executable")

    local executable = vim.fs.joinpath(Cmakeseer.get_build_directory(), target.artifacts[1].path)
    local cache = vim.fs.joinpath(M.opts.cache_directory(), string.format("%s.json", target.name))

    local cache_stat = vim.loop.fs_stat(cache)
    if cache_stat ~= nil then
      -- Cache already exists; is it outdated?
      local exe_stat = vim.loop.fs_stat(executable)
      if exe_stat ~= nil and compares_times(cache_stat.mtime, exe_stat.mtime) == 1 then
        -- Cache is not outdated; use it instead
        test_cmds[executable] = { cache = cache }
        goto continue
      end
    end

    -- Does the executable exist?
    if vim.fn.filereadable(executable) == 0 then
      goto continue
    end

    local success, test_cmd = pcall(vim.system, {
      executable,
      "--gtest_list_tests",
      string.format("--gtest_output=json:%s", cache),
    }, { timeout = 10 })
    if not success then
      vim.notify(string.format("Failed to check %s for gtests", executable), vim.log.levels.ERROR)
      goto continue
    end

    test_cmds[executable] = { cmd = test_cmd, cache = cache }
    ::continue::
  end
  return test_cmds
end

--- Refreshes the set of test directories.
local function refresh_test_directories()
  g_test_dirs = {}
  -- TODO: Almost all CWD calls actually probably need to be the project root instead. . .
  local cwd = vim.fn.getcwd()
  g_test_dirs[cwd] = true
  for executable, _ in pairs(g_test_executables_suites) do
    local path = vim.fn.fnamemodify(executable, ":h")
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

local function pass_status_test(test)
  local ResultStatus = require("neotest.types").ResultStatus

  if test.status == "NOTRUN" or test.result == "SKIPPED" then
    return ResultStatus.skipped
  end

  if test.failures == nil then
    return ResultStatus.passed
  end
  return ResultStatus.failed
end

--- Sets up the adapter.
---@return neotest.Adapter adapter The adapter.
function M.setup(opts)
  M.opts = vim.tbl_extend("keep", opts or {}, M.opts)
  -- TODO: Add a post-build callback to refresh tests
  return M
end

--- Determines if a target relies on GTest.
---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
---@return boolean does_depend If the target depends on GTest.
function M.depends_on_gtest(target)
  for _, dependency in ipairs(target.dependencies) do
    if dependency.id:match("^gtest") then
      return true
    end
  end
  return false
end

--- Determines if a target is a test from GTest, as in a test for the GTest library.
---@see depends_on_gtest
---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
---@return boolean is_gtest_test If the target is a GTest test.
function M.is_gtest_test(target)
  return target.name:match("_gtest$")
end

--- Refreshes the list of test executables.
function M.refresh_test_executables()
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  local targets = vim.tbl_filter(function(target)
    return target.type == TargetType.Executable and M.opts.target_filter(target) and M.depends_on_gtest(target)
  end, Cmakeseer.get_targets())

  g_test_executables_suites = {}
  local test_cmds = generate_executable_commands(targets)
  for executable, test_cmd in pairs(test_cmds) do
    if test_cmd.cmd ~= nil then
      -- Cache was not used
      test_cmd.cmd:wait(10)
    end

    if vim.fn.filereadable(test_cmd.cache) == 0 then
      goto continue
    end

    local file = io.open(test_cmd.cache, "r")
    if file == nil then
      goto continue
    end
    local contents = file:read("*a")
    file:close()
    local success, test_data = pcall(vim.json.decode, contents)
    if not success then
      vim.notify(
        string.format(
          "Failed to read output for executable %s; cannot detect if it is a gtest. Error: %s",
          executable,
          test_data
        ),
        vim.log.levels.WARN
      )
      vim.notify(string.format("Deleting cache for %s", executable))
      vim.fs.rm(test_cmd.cache, { force = true })
      goto continue
    end
    assert(type(test_data) == "table", "test_data was not a table")

    -- Parse the suites
    local suites, executable_files = require("cmakeseer.neotest.gtest.parsing").parse_executable_suites(test_data)
    g_test_executables_suites[executable] = suites
    g_executable_files[executable] = executable_files
    ::continue::
  end

  -- Enumerate all the test directories
  refresh_test_directories()
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.root(cwd)
  M.refresh_test_executables()
  return cwd
end

---Filter directories when searching for test files
---@async
---@param _ string Name of directory
---@param rel_path string Path to directory, relative to root
---@param project_root string Root directory of project
---@return boolean
function M.filter_dir(_, rel_path, project_root)
  local path = vim.fs.joinpath(project_root, rel_path)
  return g_test_dirs[path] ~= nil
end

---@async
---@param file_path string
---@return boolean
function M.is_test_file(file_path)
  return g_test_executables_suites[file_path] ~= nil
end

---Given a filepath, parse all the tests within it.
---@async
---@param executable_path string Absolute file path to the executable.
---@return neotest.Tree | nil
function M.discover_positions(executable_path)
  ---@type table<string, cmakeseer.neotest.gtest.treesitter.CapturedTest[]>
  local suite_tests = {}
  local executable_files = g_executable_files[executable_path]
  for file, _ in pairs(executable_files) do
    local queried_tests = M.treesitter.query_tests(file)
    if type(queried_tests) == "string" then
      vim.notify(string.format("Failed to find positions in %s: %s", file, queried_tests), vim.log.levels.ERROR)
      goto continue
    end

    for suite, tests in pairs(queried_tests) do
      if suite_tests[suite] ~= nil then
        vim.list_extend(suite_tests[suite], tests)
      else
        suite_tests[suite] = tests
      end
    end

    ::continue::
  end

  local suites = g_test_executables_suites[executable_path]
  if suites == nil then
    vim.notify_once("No suites detected for " .. executable_path, vim.log.levels.WARN)
    return nil
  end
  local structure = require("cmakeseer.neotest.gtest.structure").build(executable_path, suite_tests, suites)
  local tree = require("neotest.types.tree").from_list(structure, function(pos)
    return pos.id
  end)
  return tree
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  local Suite = require("cmakeseer.neotest.gtest.suite")

  local raw_id = args[1]
  local id_parts = vim.fn.split(raw_id, "::")
  local executable = id_parts[1]
  if executable == nil then
    vim.notify(string.format("No executable for test ID `%s`", raw_id), vim.log.levels.ERROR)
    return nil
  end

  ---@type cmakeseer.neotest.gtest.TestId
  local id = {
    executable = id_parts[1],
    suite = id_parts[2],
    test = id_parts[3],
  }

  local output_file = vim.fs.joinpath(M.opts.cache_directory(), "results.json")
  ---@type cmakeseer.neotest.gtest.Context
  local context = {
    executable = executable,
    neotest_id = raw_id,
    id = id,
    output_file = output_file,
  }
  local spec = nil
  if #id_parts == 1 then
    -- This is a file
    spec = {
      command = { executable },
    }
  elseif #id_parts == 2 then
    -- This is a suite
    local suites = g_test_executables_suites[id.executable]

    local suite_name = id.suite
    local suite_parts = vim.split(suite_name, "/")
    if #suite_parts >= 2 then
      suite_name = suite_parts[2]
    end

    ---@type cmakeseer.neotest.gtest.suite.Basic
    local suite = suites[suite_name]
    if suite == nil then
      -- TODO: Better suite name detection
      -- This happens when a ParameterizedSuite's parameter is selected
      suite = suites[suite_parts[1]]
    end

    if suite == nil then
      vim.notify("Cannot find test for " .. id.suite)
      return nil
    end

    local suite_type = Suite.type_from_suite(suite)
    if
      suite_type == Suite.Type.Basic
      or suite_type == Suite.Type.Parameterized
      or (suite_type == Suite.Type.Typed and #suite_parts == 2)
      or (suite_type == Suite.Type.ParameterizedTyped and #suite_parts == 3)
    then
      spec = {
        command = { executable, string.format("--gtest_filter=%s.*", id.suite) },
      }
    else
      spec = {
        command = { executable, string.format("--gtest_filter=%s/*.*", id.suite) },
      }
    end
  elseif #id_parts == 3 then
    -- This is an individual test
    local suites = g_test_executables_suites[id.executable]

    local suite_name = id.suite
    local suite_parts = vim.split(suite_name, "/")
    if #suite_parts >= 2 then
      suite_name = suite_parts[2]
    end
    ---@type cmakeseer.neotest.gtest.suite.Basic
    local suite = suites[suite_name]
    local suite_type = Suite.type_from_suite(suite)

    local test_parts = vim.split(id.test, "/")
    if suite_type == Suite.Type.Parameterized and #test_parts == 1 then
      -- We're a ParameterizedSuite and we don't have a specific parameter we're testing for; we'll need to do all
      spec = {
        command = {
          executable,
          "--gtest_also_run_disabled_tests",
          string.format("--gtest_filter=%s.%s/*", id.suite, id.test),
        },
      }
    else
      spec = {
        command = {
          executable,
          "--gtest_also_run_disabled_tests",
          string.format("--gtest_filter=%s.%s", id.suite, id.test),
        },
      }
    end
  else
    vim.notify(string.format("Unrecognized test ID: `%s`", raw_id), vim.log.levels.ERROR)
    return nil
  end

  assert(spec ~= nil)
  spec.context = context
  table.insert(spec.command, string.format("--gtest_output=json:%s", output_file))

  return spec
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, result, _)
  local ResultStatus = require("neotest.types").ResultStatus

  _ = result

  ---@type cmakeseer.neotest.gtest.Context
  local context = spec.context
  local fin = io.open(context.output_file, "r")
  if fin == nil then
    vim.notify("Unable to access GTest cache file", vim.log.levels.ERROR)
    return { [context.neotest_id] = { status = ResultStatus.skipped } }
  end

  local test_results = vim.json.decode(fin:read("*a"))
  fin:close()

  local file_status = ResultStatus.passed
  local results = {}
  for _, suite in ipairs(test_results.testsuites) do
    local suite_status = ResultStatus.passed
    local suite_id = string.format("%s::%s", context.id.executable, suite.name)

    for _, test in ipairs(suite.testsuite) do
      local test_id = string.format("%s::%s::%s", context.id.executable, suite.name, test.name)
      local errors = test.failures or {}
      for i, error in ipairs(errors) do
        local failure = error.failure
        local failure_parts = vim.fn.split(failure, "\n")

        -- Start by getting the line the error occurred on
        local location = table.remove(failure_parts, 1)
        local line = nil
        if location ~= "unknown file" then
          local _, line_str = unpack(vim.fn.split(location, ":"))
          line = tonumber(line_str) - 1
        end

        -- Now we'll get the message
        local msg = table.concat(failure_parts, "\n")
        ---@type neotest.Error
        errors[i] = {
          message = msg,
          line = line,
        }
      end

      local test_status = pass_status_test(test)
      results[test_id] = { status = test_status, errors = #errors >= 1 and errors or nil }
      if test_status == ResultStatus.failed then
        suite_status = ResultStatus.failed
      end
    end

    results[suite_id] = { status = suite_status }
    if suite_status == ResultStatus.failed then
      file_status = ResultStatus.failed
    end
  end

  results[context.id.executable] = { status = file_status }
  return results
end

return M
