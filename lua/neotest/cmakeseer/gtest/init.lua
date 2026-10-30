local CMakeSeer = require("cmakeseer")
local GTestJsonReport = require("cmakeseer.gtest.json_report")
local ResultStatus = require("neotest.types").ResultStatus
local TargetType = require("cmakeseer.cmake.file_api.object_kind.codemodel.target").Type

---@private
---@class neotest.cmakeseer.gtest.Context
---@field executable string
---@field neotest_id string
---@field id neotest.cmakeseer.gtest.TestId
---@field output_file string

---@private
---@class neotest.cmakeseer.gtest.TestId
---@field executable string
---@field suite string?
---@field test string?

-- TODO: Have the plugin subscribe to build events
local M
---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: table?): neotest.Adapter
M = {
  name = "CMakeSeer GTest",
  opts = {
    --- Filter out targets when looking for tests.
    ---@param target cmakeseer.cmake.file_api.object_kind.Codemodel.Target The target to test. Will be an executable.
    ---@return boolean keep If the target should be kept.
    target_filter = function(target)
      return string.match(target.name, "[tT]est") and not M.is_test_from_gtest_itself(target)
    end,
    cache_directory = function()
      return vim.fs.joinpath(CMakeSeer.resolve_build_directory(), ".cache", "cmakeseer", "gtest")
    end,
    --- DAP configuration used when tests are run with the "dap" strategy. If nil and nvim-dap is installed, a default configuration is used.
    ---@type table|nil
    dap = nil,
  },
  treesitter = require("neotest.cmakeseer.gtest.treesitter"),
}

--- Fetches and filters targets to return only the GTest executables.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target[] targets The GTest executable targets.
local function fetch_gtest_executables()
  return vim
    .iter(CMakeSeer.state.get_targets())
    :filter(function(target)
      ---@cast target cmakeseer.cmake.file_api.object_kind.Codemodel.Target
      return target.type == TargetType.Executable and M.depends_on_gtest(target) and M.opts.target_filter(target)
    end)
    :totable()
end

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
---@param target cmakeseer.cmake.file_api.object_kind.Codemodel.Target The targets to check.
---@param on_exit? fun(target: cmakeseer.cmake.file_api.object_kind.Codemodel.Target, cache: string, out?: vim.SystemCompleted)
---@return {cmd: vim.SystemObj?, cache: string} gtest_list_commnd The command.
local function execute_gtest_list_command(target, on_exit)
  assert(target.type == TargetType.Executable, "Only executable targets are supported")
  assert(target.artifacts ~= nil, "Artifacts for executable should not have been nil")
  assert(#target.artifacts == 1, "Should only have one artifact for executable")

  local executable = vim.fs.joinpath(CMakeSeer.resolve_build_directory(), target.artifacts[1])
  local cache = vim.fs.joinpath(M.opts.cache_directory(), string.format("%s.json", target.name))

  local cache_stat = vim.uv.fs_stat(cache)
  if cache_stat ~= nil then
    -- Cache already exists; is it outdated?
    local exe_stat = vim.uv.fs_stat(executable)
    if exe_stat ~= nil and compares_times(cache_stat.mtime, exe_stat.mtime) == 1 then
      -- Cache is not outdated; use it instead
      if on_exit then
        on_exit(target, cache)
      end
      return { cache = cache }
    end
  end

  -- Does the executable exist?
  if vim.fn.filereadable(executable) == 0 then
    return {}
  end

  ---@type function?
  local handle_on_exit
  if on_exit then
    handle_on_exit = function(out)
      on_exit(target, cache, out)
    end
  end

  local success, test_cmd = pcall(vim.system, {
    executable,
    "--gtest_list_tests",
    string.format("--gtest_output=json:%s", cache),
  }, nil, handle_on_exit)
  if success then
    return { cmd = test_cmd, cache = cache }
  end

  vim.notify(string.format("Failed to check %s for gtests", executable), vim.log.levels.ERROR)
  return {}
end

local function get_test_status(test)
  if test.status == "NOTRUN" or test.result == "SKIPPED" then
    return ResultStatus.skipped
  end

  if test.failures == nil then
    return ResultStatus.passed
  end
  return ResultStatus.failed
end

local function get_new_status(prev_status, new_status)
  --- Skipped has lowest priority
  if prev_status == ResultStatus.skipped then
    return new_status
  end
  -- Failed has highest priority
  if new_status == ResultStatus.failed then
    return new_status
  end

  -- prev_status is either passed or failed, and so is either equal to or higher priority to new_status
  return prev_status
end

---@type cmakeseer.cmake.file_api.object_kind.Codemodel.Target[]
local gtest_executables = nil
---@type table<string, string>
local gtest_caches = {}

local function update_state()
  gtest_executables = fetch_gtest_executables()

  for _, executable_target in pairs(gtest_executables) do
    execute_gtest_list_command(executable_target, function(target, cache, complete)
      if complete ~= nil and complete.code ~= 0 then
        vim.notify(("Failed to generate GTest info for %s: %s"):format(target.name, complete.stderr or "Unknown error"))
        return
      end

      gtest_caches[target.name] = cache
    end)
  end
end

local function executables_for_file(file_path)
  local project_root = CMakeSeer.get_config():get_project_root()
  local resolved_file_path = vim.fs.relpath(project_root, file_path) or file_path

  local executables = {}
  local total_executables = 0
  for _, target in ipairs(gtest_executables) do
    for _, source in ipairs(target.sources or {}) do
      if source.path == resolved_file_path then
        if executables[target.name] == nil then
          total_executables = total_executables + 1
        end
        executables[target.name] = target
      end
    end
  end
  return executables, total_executables
end

local setup_called = false

--- Sets up the adapter.
---@param opts table
---@return neotest.Adapter adapter The adapter.
function M.setup(opts)
  M.opts = vim.tbl_extend("keep", opts or {}, M.opts)
  if not setup_called then
    vim.api.nvim_create_autocmd("User", {
      pattern = "CMakeSeerPostbuild",
      callback = function(args)
        if args.data.status ~= "SUCCESS" then
          return
        end

        update_state()
      end,
    })
  end
  setup_called = true
  return M
end

--- Determines if a target relies on GTest.
---@param target cmakeseer.cmake.file_api.object_kind.Codemodel.Target The target to test. Will be an executable.
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
---@param target cmakeseer.cmake.file_api.object_kind.Codemodel.Target The target to test. Will be an executable.
---@return boolean is_gtest_test If the target is a GTest test.
function M.is_test_from_gtest_itself(target)
  return target.name:match("_gtest$") ~= nil
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.root(cwd)
  local project_root = CMakeSeer.get_config():get_project_root()
  local in_project = #cwd == #project_root and cwd == project_root
  in_project = in_project or (#cwd < #project_root and vim.startswith(project_root, cwd))
  in_project = in_project or (#cwd > #project_root and vim.startswith(cwd, project_root))

  if in_project then
    if not setup_called then
      M.setup()
      update_state()
    end

    return project_root
  end
  return nil
end

---Filter directories when searching for test files
---@async
---@param _directory string Name of directory
---@param rel_path string Path to directory, relative to root
---@param _project_root string Root directory of project
---@return boolean
function M.filter_dir(_directory, rel_path, _project_root)
  for _, target in ipairs(gtest_executables) do
    for _, source in ipairs(target.sources or {}) do
      for path in vim.fs.parents(source.path) do
        if path == rel_path then
          return true
        end
      end
    end
  end

  return false
end

---@async
---@param file_path string
---@return boolean
function M.is_test_file(file_path)
  local project_root = CMakeSeer.get_config():get_project_root()
  file_path = vim.fs.relpath(project_root, file_path) or file_path
  for _, target in ipairs(gtest_executables) do
    for _, source in ipairs(target.sources or {}) do
      if file_path == source.path then
        return true
      end
    end
  end

  return false
end

---Given a filepath, parse all the tests within it.
---@async
---@param file_path string Absolute file path to the test file.
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local queried_tests, err = M.treesitter.query_tests(file_path)
  if queried_tests == nil then
    vim.notify(("Failed to find positions in %s: %s"):format(file_path, err), vim.log.levels.ERROR)
    return nil
  end

  ---@type table<string, neotest.cmakeseer.gtest.treesitter.CapturedTest[]>
  local suite_tests = {}
  for suite, tests in pairs(queried_tests) do
    suite_tests[suite] = suite_tests[suite] or {}
    vim.list_extend(suite_tests[suite], tests)
  end

  ---@type table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Target>, number
  local executables, total_executables = executables_for_file(file_path)
  local _, executable_target = next(executables)
  if executable_target == nil then
    vim.notify_once("No suites detected for " .. file_path, vim.log.levels.WARN)
    return nil
  end
  if total_executables > 1 then
    -- TODO: Support multiple executables per file
    vim.notify(("Multiple executables are not yet supported. Running %s"):format(executable_target.name), vim.log.levels.WARN)
  end

  local gtest_cache = gtest_caches[executable_target.name]
  if gtest_cache == nil then
    vim.notify(("Could not find gtest report for %s"):format(executable_target.name))
    return nil
  end

  local report
  report, err = GTestJsonReport.try_from_file(gtest_cache)
  if report == nil then
    vim.notify(("Failed to read output for executable %s; cannot detect if it is a gtest. Error: %s"):format(executable_target.name, err), vim.log.levels.ERROR)
    vim.notify(("Deleting cache for %s"):format(executable_target.name))
    vim.fs.rm(gtest_cache, { force = true })
    return nil
  end

  local relevant_suites = report.testsuites
  local structure = require("neotest.cmakeseer.gtest.structure").build(file_path, suite_tests, relevant_suites)
  local tree = require("neotest.types.tree").from_list(structure, function(pos)
    return pos.id
  end)
  return tree
end

local function parse_id(id)
  local id_parts = vim.split(id, "::", { plain = true })
  local id_type = id_parts[2]

  if id_type == "suite" then
    return { file = id_parts[1], type = id_type, suite = id_parts[4], suite_type = id_parts[3], name = "*" }
  elseif id_type == "basic" or id_type == "unknown" then
    return { file = id_parts[1], type = id_type, suite = id_parts[3], name = id_parts[4] or "*" }
  elseif id_type == "typed" then
    return { file = id_parts[1], type = id_type, suite = id_parts[3], name = id_parts[4] or "*", postfix = id_parts[5] or "*" }
  elseif id_type == "parameterized" then
    return { file = id_parts[1], type = id_type, suite = id_parts[3], name = id_parts[4] or "*", prefix = id_parts[5] or "*", postfix = id_parts[6] or "*" }
  elseif id_type == "parameterized_typed" then
    return { file = id_parts[1], type = id_type, suite = id_parts[3], name = id_parts[4] or "*", prefix = id_parts[5] or "*", postfix = id_parts[6] or "*" }
  end

  local stat = vim.uv.fs_stat(id)
  if stat and stat.type == "directory" then
    return { type = "dir", file = id }
  end
  return { type = "file", file = id }
end

-- TODO: These ought to be classes-- we need more complex capabilities for these IDs
-- - ID to gtest filter
-- - ID to string
-- - disabled()
-- others?

--- Creates a filter for all tests in a file.
---@param file string The path to the file.
---@return string? filter The filter, if it was able to be constructed.
local function file_to_filter(file)
  local queried_tests, err = M.treesitter.query_tests(file)
  if queried_tests == nil then
    vim.notify(("Failed to find positions in %s: %s"):format(file, err), vim.log.levels.ERROR)
    return nil
  end

  -- TRICKY: We deliberately DON'T filter out the disabled tests so we can mark them as skipped in the output.
  -- If we exclude them, Neotest will automatically mark them as whatever the file is marked as.
  local tests = {}
  for _, v in pairs(queried_tests) do
    table.insert(tests, v)
  end
  local filters = vim
    .iter(tests)
    :flatten()
    :map( ---@diagnostic disable-line: undefined-field
      function(test)
        ---@cast test neotest.cmakeseer.gtest.treesitter.CapturedTest
        local format
        if test.type == "basic" then
          format = "%s.%s"
        elseif test.type == "typed" then
          format = "%s/*.%s"
        elseif test.type == "parameterized" then
          format = "*/%s.%s/*"
        elseif test.type == "parameterized_typed" then
          format = "*/%s/*.%s"
        end
        return assert(format):format(test.suite, test.name)
      end
    )
    :totable()
  return table.concat(filters, ":")
end

--- Converts a test ID to a GTest filter.
---@param test_id table The ID.
---@return string? filter The filter, if it was able to be constructed.
local function id_to_filter(test_id)
  -- Yeah, Google did a great job making these reasonable to build.
  -- Though I suppose you can identify the test type just from the delimiters.
  local filter
  if test_id.type == "file" then
    filter = file_to_filter(test_id.file)
  elseif test_id.type == "suite" then
    filter = ""
    if test_id.suite_type == "parameterized" or test_id.suite_type == "parameterized_typed" then
      filter = "*/"
    end
    filter = filter .. test_id.suite
    if test_id.suite_type == "parameterized_typed" or test_id.suite_type == "typed" then
      filter = filter .. "/*"
    end
    filter = filter .. ".*"
  elseif test_id.type == "basic" then
    filter = ("%s.%s"):format(test_id.suite, test_id.name)
  elseif test_id.type == "typed" then
    filter = ("%s/%s.%s"):format(test_id.suite, test_id.postfix, test_id.name)
  elseif test_id.type == "parameterized" then
    filter = ("%s/%s.%s/%s"):format(test_id.prefix, test_id.suite, test_id.name, test_id.postfix)
  elseif test_id.type == "parameterized_typed" then
    filter = ("%s/%s/%s.%s"):format(test_id.prefix, test_id.suite, test_id.postfix, test_id.name)
  end
  return filter
end

--- Builds the dap configuration for the dap strategy.
---@param target_name string The executable target to run.
---@param command_args string[] The command and its args.
---@return table? config, string? err The dap configuration.
local function build_dap_config(target_name, command_args)
  local config = M.opts.dap
  if config == nil then
    local ok, dap = pcall(require, "dap")
    if not ok then
      return nil, "nvim-dap is not installed; cannot use the dap strategy"
    end

    -- Detect the adapter type from the installed adapters, falling back to
    -- "cppdbg" (ms-vscode.cpptools) when none of the known ones are present.
    local adapter_type = "cppdbg"
    local adapters = dap.adapters or {}
    for _, candidate in ipairs({ "cppdbg", "cpp", "codelldb" }) do
      if adapters[candidate] ~= nil then
        adapter_type = candidate
        break
      end
    end

    config = {
      type = adapter_type,
      request = "launch",
    }
  end

  return vim.tbl_deep_extend("force", config, {
    type = config.type or "cppdbg",
    request = config.request or "launch",
    name = ("CMakeSeer GTest: %s"):format(target_name),
    program = command_args[1],
    args = vim.iter(command_args):skip(1):totable(),
  })
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  local original_test_id = parse_id(args[1])
  if original_test_id.type == "unknown" or original_test_id.suite_type == "unknown" then
    vim.notify("Recompile before running tests", vim.log.levels.ERROR)
    return {}
  end

  local test_ids = {}
  if original_test_id.type == "dir" then
    -- We'll fetch all the file IDs
    local tree = args.tree
    for _, child in tree:iter() do
      if child.type == "file" then
        table.insert(test_ids, parse_id(child.id))
      end
    end
  else
    table.insert(test_ids, original_test_id)
  end

  ---@type table<string, {target: cmakeseer.cmake.file_api.object_kind.Codemodel.Target, ids: table[]}>
  local executable_targets = {}
  local total_executable_targets = 0
  for _, test_id in ipairs(test_ids) do
    local executables, total_executables = executables_for_file(test_id.file)
    if total_executables == 0 then
      vim.notify("No suites detected for " .. test_id.file, vim.log.levels.WARN)
      return {}
    end

    for _, executable_target in pairs(executables) do
      if executable_targets[executable_target.name] == nil then
        total_executable_targets = total_executable_targets + 1
        executable_targets[executable_target.name] = {
          target = executable_target,
          ids = {},
        }
      end
      table.insert(executable_targets[executable_target.name].ids, test_id)
    end
  end

  assert(total_executable_targets > 0, "Should never be 0 because we're checking inside the loop as well")
  local strategy = args.strategy
  if strategy == "dap" and total_executable_targets > 1 then
    vim.notify(("Cannot run DAP with more than one executable. Found %d for %s"):format(total_executable_targets, original_test_id.file), vim.log.levels.WARN)
    return {}
  end

  local specs = {}
  local build_dir = CMakeSeer.resolve_build_directory()
  for _, target_and_ids in pairs(executable_targets) do
    local executable_target = target_and_ids.target
    local executable_test_ids = target_and_ids.ids

    local report_path = vim.fs.joinpath(M.opts.cache_directory(), "reports", (executable_target.name_on_disk or executable_target.name) .. ".json")

    assert(#executable_target.artifacts == 1, "Should only ever have exactly 1 artifact")
    local command = executable_target.artifacts[1]
    if vim.fn.isabsolutepath(command) == 0 then
      command = vim.fs.joinpath(build_dir, command)
    end

    local filter
    local has_disabled = false
    for _, test_id in ipairs(executable_test_ids) do
      local new_filter = id_to_filter(test_id)
      if new_filter == nil then
        vim.notify(("Failed to generate gtest filter for %s"):format(test_id.name), vim.log.levels.ERROR)
        return {}
      end
      if filter then
        filter = ("%s:%s"):format(filter, new_filter)
      else
        filter = new_filter
      end
      local suite_is_disabled = test_id.suite and vim.startswith(test_id.suite, "DISABLED_")
      local test_is_disabled = test_id.name and vim.startswith(test_id.name, "DISABLED_")
      has_disabled = has_disabled or suite_is_disabled or test_is_disabled
    end
    assert(filter, "Should have had at least one test ID")

    local command_args = {
      command,
      ("--gtest_output=json:%s"):format(report_path),
      ("--gtest_filter=%s"):format(filter),
    }

    if has_disabled then
      table.insert(command_args, "--gtest_also_run_disabled_tests")
    end

    ---@type neotest.RunSpec
    local spec = {
      command = command_args,
      ---@class neotest.cmakeseer.Context
      ---@field executable cmakeseer.cmake.file_api.object_kind.Codemodel.Target
      ---@field report_path string
      ---@field raw_id string
      ---@field original_test_id table
      context = {
        executable = executable_target,
        report_path = report_path,
        raw_id = args[1],
        original_test_id = original_test_id,
      },
    }
    table.insert(specs, spec)
  end

  if strategy == "dap" then
    assert(#specs == 1)
    local dap_config = build_dap_config(specs[1].context.executable.name, specs[1].command)
    if dap_config == nil then
      vim.notify("Failed to build dap configuration for " .. original_test_id.file, vim.log.levels.ERROR)
      return {}
    end
    specs[1].strategy = dap_config
  end
  return specs
end

---@async
---@param spec neotest.RunSpec
---@param exe_result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, exe_result, _)
  ---@type neotest.cmakeseer.Context?
  local context = spec.context
  if context == nil then
    return {}
  end

  local report, err = GTestJsonReport.try_from_file(context.report_path)
  if report == nil then
    vim.notify(("Failed to read GTest output for executable %s; cannot parse results. Error: %s"):format(context.executable.name, err), vim.log.levels.ERROR)
    return {
      [context.raw_id] = {
        status = exe_result.code == 0 and ResultStatus.passed or ResultStatus.failed,
        output = exe_result.output,
      },
    }
  end

  -- Get the result for every test that was run
  ---@type table<string, neotest.Result>
  local results = {}
  ---@type table<string, neotest.ResultStatus>
  local file_statuses = {}
  for _, suite in pairs(report.testsuites) do
    local suite_type = suite.type
    ---@type table<string, neotest.ResultStatus>
    local suite_statuses = {} -- We need multiple statuses in case the suite spans multiple files
    for _, test in ipairs(suite.tests) do
      local test_status = get_test_status(test)

      suite_statuses[test.file] = suite_statuses[test.file] or ResultStatus.skipped
      suite_statuses[test.file] = get_new_status(suite_statuses[test.file], test_status)

      file_statuses[test.file] = file_statuses[test.file] or ResultStatus.skipped
      file_statuses[test.file] = get_new_status(file_statuses[test.file], test_status)

      local test_id = ("%s::%s::%s::%s"):format(test.file, test.type, suite.name, test.name)
      if test.type == "typed" then
        -- Set the test name status
        results[test_id] = results[test_id] or {
          status = ResultStatus.skipped,
          output = exe_result.output,
        }
        results[test_id].status = get_new_status(results[test_id].status, test_status)

        test_id = ("%s::%s"):format(test_id, test.variant)
      elseif test.type == "parameterized" or test.type == "parameterized_typed" then
        -- Set the test name status
        results[test_id] = results[test_id] or {
          status = ResultStatus.skipped,
          output = exe_result.output,
        }
        results[test_id].status = get_new_status(results[test_id].status, test_status)

        -- Set the prefix status
        test_id = ("%s::%s"):format(test_id, test.prefix)
        results[test_id] = results[test_id] or {
          status = ResultStatus.skipped,
          output = exe_result.output,
        }
        results[test_id].status = get_new_status(results[test_id].status, test_status)

        test_id = ("%s::%s"):format(test_id, test.postfix)
      end

      ---@type neotest.Error[]?
      local errors
      if test_status == ResultStatus.failed then
        errors = {}
        for _, failure in ipairs(test.failures) do
          -- A failure looks something like
          -- "~/cmakeseer/spec/fixtures/cmake/projects/gtest/basic_test.cpp:6\nExpected equality of these values:\n  1\n  2\n"
          local parts = vim.split(failure.failure, "\n", { plain = true })
          local location = parts[1]
          local location_parts = vim.split(location, ":", { plain = true })
          local line = tonumber(location_parts[#location_parts]) or 1
          line = line - 1

          local message_parts = vim.iter(parts):skip(1):map(vim.trim):totable()
          local message = vim.trim(table.concat(message_parts, "\n"))
          table.insert(
            errors,
            ---@type neotest.Error
            {
              message = message,
              line = line,
            }
          )
        end
      end

      ---@type neotest.Result
      local test_result = {
        status = test_status,
        output = exe_result.output,
        errors = errors,
      }

      results[test_id] = test_result
    end

    for file, suite_status in pairs(suite_statuses) do
      local suite_id = ("%s::suite::%s::%s"):format(file, suite_type, suite.name)
      ---@type neotest.Result
      local suite_result = {
        status = suite_status,
        output = exe_result.output,
      }
      results[suite_id] = suite_result
    end
  end

  for file, status in pairs(file_statuses) do
    results[file] = {
      status = status,
      output = exe_result.output,
    }
  end

  return results
end

return M
