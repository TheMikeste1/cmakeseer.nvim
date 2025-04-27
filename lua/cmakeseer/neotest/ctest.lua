local NeotestTypes = require("neotest.types")
local NeotestLib = require("neotest.lib")
local Cmakeseer = require("cmakeseer")

---@type table<string, neotest.Result>
local g_test_results = {}

---@private
---@param str string The string to escape.
---@return string str The escaped string.
local function __escape_regex(str)
  return vim.fn.escape(str, "^$.*?\\[]()~")
end

---@private
---@param test cmakeseer.cmake.api.Test The test for which to generate the command.
---@return string[] command The command that fails.
local function __generate_test_command(test)
  local escaped_test_name = __escape_regex(test.name)
  return { "ctest", "--test-dir", Cmakeseer.get_build_directory(), "-R", escaped_test_name }
end

---@private
---@param file_path string The absolute path to the file whose nodes should be fetched.
---@return [number, cmakeseer.cmake.api.Node]? maybe_nodes The nodes associated with the file. Nil if the file isn't recognized.
local function __get_nodes_for_file(file_path)
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return nil
  end

  local file_index = 0
  local files = maybe_info.backtraceGraph.files
  for i, file in ipairs(files) do
    if file_path == file then
      file_index = i
    end
  end

  if file_index == 0 then
    return nil
  end

  file_index = file_index - 1

  local nodes = maybe_info.backtraceGraph.nodes
  ---@type [number, cmakeseer.cmake.api.Node]
  local file_nodes = {}
  for node_index, node in ipairs(nodes) do
    if node.file == file_index then
      node_index = node_index - 1
      table.insert(file_nodes, { node_index, node })
    end
  end
  return file_nodes
end

---@private
--- Generates a neotest.RunSpec for all tests in a file.
---@param file string The name of the file containing the tests.
---@return neotest.RunSpec | nil specs A RunSpec to run all tests in the file.
local function __get_file_test_run_spec(file)
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return nil
  end

  local nodes = __get_nodes_for_file(file)
  if nodes == nil then
    return nil
  end

  local test_names = {}
  local test_ids = {}
  local test_indices = {}
  local tests = maybe_info.tests

  for i, test in ipairs(tests) do
    for _, index_and_node in ipairs(nodes) do
      local node_index = index_and_node[1]

      if test.backtrace == node_index then
        local escaped_test_name = __escape_regex(test.name)
        table.insert(test_names, escaped_test_name)
        table.insert(test_ids, file .. "::" .. test.name)
        table.insert(test_indices, i)
        break
      end
    end
  end

  if #test_names == 0 then
    return nil
  end

  local test_regex = test_names[1]

  local i = 1
  while i < #test_names do
    i = i + 1
    test_regex = string.format("%s|%s", test_regex, test_names[i])
  end

  ---@type neotest.RunSpec
  return {
    command = { "ctest", "--test-dir", Cmakeseer.get_build_directory(), "-R", test_regex },
    context = {
      ids = test_ids,
      test_indices = test_indices,
    },
  }
end

---@private
--- Generates a neotest.RunSpec[] for all tests in a file.
---@param file string The name of the file containing the tests.
---@return neotest.RunSpec[] | nil specs The run specs in the file.
local function __get_file_test_run_specs(file)
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return nil
  end

  local nodes = __get_nodes_for_file(file)
  if nodes == nil then
    return nil
  end

  ---@type neotest.RunSpec[]
  local specs = {}
  local tests = maybe_info.tests
  for i, test in ipairs(tests) do
    for _, index_and_node in ipairs(nodes) do
      local node_index = index_and_node[1]

      if test.backtrace == node_index then
        local command = __generate_test_command(test)
        ---@type neotest.RunSpec
        local spec = {
          command = command,
          context = { id = file .. "::" .. test.name, test_index = i },
        }
        table.insert(specs, spec)
        break
      end
    end
  end

  return specs
end

---@private
--- Generates a neotest.RunSpec given a test's ID.
---@param id string The ID the test.
---@param test_name string The name, of the test.
---@return neotest.RunSpec | nil spec The run spec, if the test exists.
local function __get_test_run_spec_by_id(id, test_name)
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return nil
  end

  local tests = maybe_info.tests
  for i, test in ipairs(tests) do
    if test.name == test_name then
      local command = __generate_test_command(test)
      ---@type neotest.RunSpec
      return {
        command = command,
        context = { id = id, test_index = i },
      }
    end
  end

  vim.notify(string.format("Unknown test ID: %s", id), vim.log.levels.ERROR)
  return nil
end

---@private
---@param output_lines string[] The output lines from the CTest call.
---@return table<string, neotest.Result>
local function __parse_ctest_failures(output_lines)
  local i = 0

  -- Move to the errors
  while i < #output_lines do
    i = i + 1
    if output_lines[i] == "The following tests FAILED:" then
      break
    end
  end

  local error_lines = {}
  while i < #output_lines do
    i = i + 1
    local line = output_lines[i]
    if line == "" then
      goto continue
    end

    if line == "Errors while running CTest" or line:sub(1, 1) ~= "\t" then
      break
    end
    table.insert(error_lines, line)
    ::continue::
  end

  ---@type table<string, neotest.Result>
  local results = {}
  for _, line in ipairs(error_lines) do
    local s, e = line:reverse():find("%)[^%(]+%(")
    local end_name = #line - e

    local _, start_name = line:find(" - ", 0, true)
    local test_name = line:sub(start_name + 1, end_name - 1)

    local status_string = line:sub(end_name + 2, #line - s)
    local status = NeotestTypes.ResultStatus.failed
    if status_string == "Not Run" then
      status = NeotestTypes.ResultStatus.skipped
    end
    results[test_name] = { status = status }
  end

  return results
end

---@class cmakeseer.CTestAdapterOpts
---@field parallel_instances boolean If the adapter should spawn multiple instances running in parallel when running tests.

---@class cmakeseer.CTestAdapter : neotest.Adapter
---@field __options cmakeseer.CTestAdapterOpts
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter

---@type cmakeseer.CTestAdapter
---@diagnostic disable-next-line: missing-fields
local M = {
  name = "CMakeSeer CTest",
  __options = { parallel_instances = false },
}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.root(cwd)
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
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return false
  end

  local files = maybe_info.backtraceGraph.files
  for _, file in ipairs(files) do
    if file_path == file then
      return true
    end
  end

  return false
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local maybe_info = Cmakeseer.get_ctest_info()
  if maybe_info == nil then
    return nil
  end

  local file_index = 0
  local files = maybe_info.backtraceGraph.files
  for i, file in ipairs(files) do
    if file_path == file then
      file_index = i
    end
  end

  if file_index == 0 then
    vim.notify("Failed to find tests in " .. file_path, vim.log.levels.ERROR)
    return nil
  end

  file_index = file_index - 1

  local file = io.open(file_path, "r")
  if file == nil then
    vim.notify("Could not open file. Failed to find tests in " .. file_path, vim.log.levels.ERROR)
    return nil
  end

  local num_lines = 0
  local final_line_length = 0
  for line in file:lines() do
    num_lines = num_lines + 1
    final_line_length = #line
  end

  if num_lines == 0 then
    return nil
  end

  local nodes = __get_nodes_for_file(file_path)
  if nodes == nil then
    return nil
  end

  local tests = maybe_info.tests
  local relative_path = vim.fs.relpath(vim.fn.getcwd(), file_path) or file_path
  ---@type neotest.Position[]
  local positions = {
    {
      id = file_path,
      type = "file",
      path = file_path,
      name = relative_path,
      range = { 0, 0, num_lines - 1, final_line_length - 1 }, -- TSNode:range
    },
  }

  local line_num = num_lines
  for _, index_and_node in ipairs(nodes) do
    local node_index = index_and_node[1]
    local node = index_and_node[2]
    if node.line == nil then
      goto continue
    end

    local line_length = 1
    if node.line < line_num then
      file:seek("set")
      line_num = 0
    end

    if line_num < node.line then
      for line in file:lines() do
        line_num = line_num + 1
        if line_num == node.line then
          line_length = #line
          break
        end
      end
    end

    for _, test in ipairs(tests) do
      if test.backtrace == node_index then
        ---@type neotest.Position
        local position = {
          id = test.name,
          type = "test",
          name = test.name,
          path = file_path,
          range = { node.line - 1, 0, node.line - 1, line_length - 1 },
        }
        positions[#positions + 1] = position
      end
    end
    ::continue::
  end

  file:close()

  local tree = NeotestLib.positions.parse_tree(positions, { nested_tests = true })
  return tree
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  local id = args[1]
  local id_parts = vim.fn.split(id, "::")
  if #id_parts == 1 then
    if M.__options.parallel_instances then
      return __get_file_test_run_specs(id)
    else
      return __get_file_test_run_spec(id)
    end
  end

  local test_name = table.concat(id_parts, "::", 2)
  return __get_test_run_spec_by_id(id, test_name)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, result, _)
  local context = spec.context
  assert(context ~= nil, "Did not get context for test")

  local id = context.id
  if id ~= nil then
    local test_result = { status = NeotestTypes.ResultStatus.passed }
    if result.code ~= 0 then
      assert(vim.fn.glob(result.output) ~= "", "Output file should exist")
      local output = vim.fn.readfile(result.output)
      local test_results = __parse_ctest_failures(output)

      local k, v = next(test_results)
      assert(v ~= nil, string.format("No error found: %s", vim.inspect(v)))
      test_result = v or { status = NeotestTypes.ResultStatus.skipped }
      assert(next(test_results, k) == nil, "There should only be one error")
    end

    g_test_results[id] = test_result
  else
    local ids = context.ids
    assert(id ~= nil or ids ~= nil, "Context did not have an id")

    if result.code == 0 then
      -- If CTest exited with 0, we can take a shortcut and just pass all the tests.
      local status = NeotestTypes.ResultStatus.passed
      for _, test_id in ipairs(ids) do
        g_test_results[test_id] = {
          status = status,
        }
      end
    else
      local tests = Cmakeseer.get_ctest_tests()
      assert(tests ~= nil)

      assert(vim.fn.glob(result.output) ~= "", "Output file should exist")
      local output = vim.fn.readfile(result.output)
      local test_results = __parse_ctest_failures(output)
      for i, test_id in ipairs(ids) do
        local test_index = context.test_indices[i]
        local test_name = tests[test_index].name
        local test_result = test_results[test_name] or { status = NeotestTypes.ResultStatus.passed }
        g_test_results[test_id] = test_result
      end
    end
  end

  return g_test_results
end

--- Sets up the adapter.
---@param opts cmakeseer.CTestAdapterOpts? The options for the adapter.
---@return neotest.Adapter adapter The adapter.
function M.setup(opts)
  opts = opts or {}
  M.__options = vim.tbl_deep_extend("force", M.__options, opts)
  return M
end

return M
