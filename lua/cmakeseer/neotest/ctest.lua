local NeotestTypes = require("neotest.types")
local NeotestLib = require("neotest.lib")
local Cmakeseer = require("cmakeseer")

---@type table<string, neotest.Result>
local g_test_results = {}

---@private
---@param test_name string The name of the test that should fail.
---@return string[] command The command that fails.
local function __generate_failing_command(test_name)
  return {
    "sh",
    "-c",
    string.format("echo 'Binary for %s doesn'\"'\"'t exist. . .' && exit 1", test_name),
  }
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
--- Generates a neotest.RunSpec[] for all tests in a file.
---@param file string The name of the file containing the tests.
---@return neotest.RunSpec[] | nil specs The run specs in the file.
local function __get_file_test_run_spec(file)
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

      if test.backtrace ~= node_index then
        goto continue
      end

      if test.command == nil then
        vim.notify(
          string.format("%s has an invalid command. Does the binary used exist?", test.name),
          vim.log.levels.WARN
        )
        table.insert(specs, {
          command = __generate_failing_command(test.name),
          context = { id = file .. "::" .. test.name, test_index = i },
        })
        goto continue
      end

      local cwd = nil
      for _, prop in ipairs(test.properties) do
        if prop.name == "WORKING_DIRECTORY" then
          cwd = prop.value
          break
        end
      end

      ---@type neotest.RunSpec
      local spec = {
        command = test.command,
        cwd = cwd,
        context = { id = file .. "::" .. test.name, test_index = i },
      }
      table.insert(specs, spec)

      ::continue::
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
      if test.command == nil then
        vim.notify(
          string.format("%s has an invalid command. Does the binary used exist?", test_name),
          vim.log.levels.WARN
        )
        return {
          command = __generate_failing_command(test_name),
          context = { id = id, test_index = i },
        }
      end

      local cwd = nil
      for _, prop in ipairs(test.properties) do
        if prop.name == "WORKING_DIRECTORY" then
          cwd = prop.value
          break
        end
      end

      ---@type neotest.RunSpec
      return {
        command = test.command,
        cwd = cwd,
        context = { id = id, test_index = i },
      }
    end
  end

  vim.notify(string.format("Unknown test ID: %s", id), vim.log.levels.ERROR)
  return nil
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
local function root(cwd)
  return cwd
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param project_root string Root directory of project
---@return boolean
local function filter_dir(name, rel_path, project_root)
  return name ~= "__cmake_systeminformation"
    and vim.fs.joinpath(project_root, rel_path) ~= Cmakeseer.get_build_directory()
end

---@async
---@param file_path string
---@return boolean
local function is_test_file(file_path)
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
local function discover_positions(file_path)
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
local function build_spec(args)
  local id = args[1]
  local id_parts = vim.fn.split(id, "::")
  if #id_parts == 1 then
    return __get_file_test_run_spec(id)
  end

  local test_name = table.concat(id_parts, "::", 2)
  return __get_test_run_spec_by_id(id, test_name)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
local function results(spec, result, _)
  local context = spec.context
  assert(context ~= nil, "Did not get context for test")

  local id = context.id
  assert(id ~= nil, "Context did not have an id")

  local status = NeotestTypes.ResultStatus.passed
  if result.code ~= 0 then
    status = NeotestTypes.ResultStatus.failed
  end

  g_test_results[context.id] = {
    status = status,
  }

  ---@type table<string, neotest.Result>
  return g_test_results
end

---@type neotest.Adapter
return {
  name = "CMakeSeer CTest",
  discover_positions = discover_positions,
  is_test_file = is_test_file,
  root = root,
  build_spec = build_spec,
  results = results,
  filter_dir = filter_dir,
}
