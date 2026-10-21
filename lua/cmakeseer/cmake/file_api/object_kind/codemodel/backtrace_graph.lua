---@class cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode
---@field file string The file where the backtrace node occurs. Will be relative if in the top-level source directory. Otherwise, absolute.
---@field line? number The unsigned, 1-based line number in the file. Only present if associated with a line.
---@field command? string The command invocation in the file, if it has one.
---@field parent? number The index to the parent node in the backtrace graph. 1-based. Only present if it has a parent.

--- A graph of backtraces. Its nodes are backtrace members.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph
---@field nodes cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode[] The nodes making up the backtrace graph.
local BacktraceGraph = {}
BacktraceGraph.__index = BacktraceGraph

--- Creates a new BacktraceGraph instance.
---@param nodes cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode[] The nodes making up the backtrace graph.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph obj The new instance.
function BacktraceGraph.new(nodes)
  return BacktraceGraph.take(vim.deepcopy(nodes))
end

--- Creates a new BacktraceGraph instance, taking ownership of the passed values.
---@param nodes cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode[] The nodes making up the backtrace graph.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph obj The new instance.
function BacktraceGraph.take(nodes)
  local self = setmetatable({ nodes = nodes }, BacktraceGraph)
  return self
end

---Tries to build a BacktraceNode from JSON.
---@param node any The JSON for the node.
---@param raw_files string[] The files associated with the BacktraceGraph.
---@param raw_commands string[] The commands associated with the BacktraceGraph.
---@param raw_nodes any[] The nodes associated with the BacktraceGraph.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode? node, string? err The new instance if successful. Otherwise an error.
local function try_node_from_json(node, raw_files, raw_commands, raw_nodes)
  if type(node) ~= "table" then
    return nil, "is wrong type: " .. type(node)
  end

  local file_index = node.file
  if type(file_index) ~= "number" then
    return nil, "file is wrong type: " .. type(file_index)
  end
  if file_index < 0 or file_index >= #raw_files then
    return nil, ("file index out of range: %d"):format(file_index)
  end
  local file = raw_files[file_index + 1]

  ---@type number?
  local line = node.line
  if line ~= nil and type(line) ~= "number" then
    return nil, "line is wrong type: " .. type(line)
  end

  ---@type string?
  local command
  local command_index = node.command
  if command_index ~= nil then
    if type(command_index) ~= "number" then
      return nil, "command is wrong type: " .. type(command_index)
    end

    if command_index < 0 or command_index >= #raw_commands then
      return nil, ("command index out of range: %d"):format(command_index)
    end

    command = raw_commands[command_index + 1]
  end

  ---@type number?
  local parent
  local parent_index = node.parent
  if parent_index ~= nil then
    if type(parent_index) ~= "number" then
      return nil, "parent is wrong type: " .. type(parent_index)
    end
    if parent_index < 0 or parent_index >= #raw_nodes then
      return nil, ("parent out of range: %d"):format(parent_index)
    end
    parent = parent_index + 1
  end

  ---@type cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode
  return {
    file = file,
    line = line,
    command = command,
    parent = parent,
  }
end

--- Creates a new BacktraceGraph instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph? obj, string? err The new instance if successful. Otherwise an error.
function BacktraceGraph.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local raw_nodes = json.nodes
  if type(raw_nodes) ~= "table" or not vim.islist(raw_nodes) then
    return nil, "nodes is wrong type: " .. type(raw_nodes)
  end

  local raw_commands = json.commands
  if type(raw_commands) ~= "table" or not vim.islist(raw_commands) then
    return nil, "commands is wrong type: " .. type(raw_commands)
  end

  local raw_files = json.files
  if type(raw_files) ~= "table" or not vim.islist(raw_files) then
    return nil, "files is wrong type: " .. type(raw_files)
  end

  for i, command in ipairs(raw_commands) do
    if type(command) ~= "string" then
      return nil, ("command at index %d is wrong type: %s"):format(i, type(command))
    end
  end
  ---@cast raw_commands string[]

  for i, file in ipairs(raw_files) do
    if type(file) ~= "string" then
      return nil, ("file at index %d is wrong type: %s"):format(i, type(file))
    end
  end
  ---@cast raw_files string[]

  ---@type cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode[]
  local nodes = {}
  for i, raw_node in ipairs(raw_nodes) do
    local node, err = try_node_from_json(raw_node, raw_files, raw_commands, raw_nodes)
    if node == nil then
      return nil, ("node at index %d: %s"):format(i, err)
    end

    table.insert(nodes, node)
  end

  return BacktraceGraph.take(nodes)
end

return BacktraceGraph
