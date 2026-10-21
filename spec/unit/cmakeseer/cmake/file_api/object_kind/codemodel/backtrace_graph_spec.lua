local BacktraceGraph = require("cmakeseer.cmake.file_api.object_kind.codemodel.backtrace_graph")

---A valid backtrace graph object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    nodes = {
      { file = 0 },
      { file = 1, line = 48, command = 0, parent = 0 },
    },
    commands = { "install" },
    files = { "CMakeLists.txt", "math/CMakeLists.txt" },
  }, overrides or {})
end

---The nodes of the backtrace graph the fixture json describes.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceNode[] nodes
local function valid_nodes()
  return {
    { file = "CMakeLists.txt", line = nil, command = nil, parent = nil },
    { file = "math/CMakeLists.txt", line = 48, command = "install", parent = 1 },
  }
end

---A valid node, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_node_json(overrides)
  return vim.tbl_extend("force", { file = 0, line = 48, command = 0, parent = 0 }, overrides or {})
end

describe("BacktraceGraph", function()
  describe("new", function()
    it("initializes correctly", function()
      local graph = BacktraceGraph.new(valid_nodes())
      assert.are.same(valid_nodes(), graph.nodes)
    end)

    it("does not share the nodes with the caller", function()
      local nodes = valid_nodes()

      local graph = BacktraceGraph.new(nodes)
      nodes[1].file = "other/CMakeLists.txt"
      nodes[2].parent = nil

      assert.are.equal("CMakeLists.txt", graph.nodes[1].file)
      assert.are.equal(1, graph.nodes[2].parent)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local graph = BacktraceGraph.take(valid_nodes())
      assert.are.same(valid_nodes(), graph.nodes)
    end)

    -- `take` exists so that a caller that just parsed the nodes does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local nodes = valid_nodes()

      local graph = BacktraceGraph.take(nodes)
      nodes[1].file = "other/CMakeLists.txt"

      assert.are.equal("other/CMakeLists.txt", graph.nodes[1].file)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "backtraceGraph" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local graph, err = BacktraceGraph.try_from_json(value)
        assert.is_nil(graph)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_nodes(), assert(graph).nodes)
    end)

    it("resolves the file index of a node into the file it names", function()
      local json = valid_json({ nodes = { { file = 1 } } })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("math/CMakeLists.txt", assert(graph).nodes[1].file)
    end)

    it("resolves the command index of a node into the command it names", function()
      local json = valid_json({ commands = { "add_subdirectory", "install" }, nodes = { valid_node_json({ command = 1 }) } })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("install", assert(graph).nodes[1].command)
    end)

    -- CMake writes the indices of the graph members zero-based and they address Lua tables one-based.
    it("resolves the parent index of a node into the node it names", function()
      local json = valid_json({ nodes = { { file = 0 }, valid_node_json({ parent = 0 }) } })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal(1, assert(graph).nodes[2].parent)
    end)

    it("leaves the optional members of a node absent when the json omits them", function()
      local json = valid_json({ nodes = { { file = 0 } } })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.same({ { file = "CMakeLists.txt", line = nil, command = nil, parent = nil } }, assert(graph).nodes)
    end)

    it("accepts a graph with no nodes, commands, or files", function()
      local json = valid_json({ nodes = {}, commands = {}, files = {} })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.same({}, assert(graph).nodes)
    end)

    it("does not share the nodes with the json", function()
      local json = valid_json()

      local graph = assert(BacktraceGraph.try_from_json(json))
      json.nodes[1].file = "other/CMakeLists.txt"

      assert.are.equal("CMakeLists.txt", graph.nodes[1].file)
    end)

    for _, field in ipairs({ "nodes", "commands", "files" }) do
      it(("returns an error when %s is missing"):format(field), function()
        local json = valid_json()
        json[field] = nil

        local graph, err = BacktraceGraph.try_from_json(json)
        assert.is_nil(graph)
        assert.are.equal(("%s is wrong type: nil"):format(field), err)
      end)

      for _, entry in ipairs({
        { "a number", 42 },
        { "a boolean", true },
        { "a string", "invalid" },
        { "a dict instead of a list", { first = 1 } },
      }) do
        local label, value = entry[1], entry[2]
        it(("returns an error when %s is %s"):format(field, label), function()
          local graph, err = BacktraceGraph.try_from_json(valid_json({ [field] = value }))
          assert.is_nil(graph)
          assert.are.equal(("%s is wrong type: %s"):format(field, type(value)), err)
        end)
      end
    end

    it("returns an error when a command is not a string", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ commands = { "install", 42 } }))
      assert.is_nil(graph)
      assert.are.equal("command at index 2 is wrong type: number", err)
    end)

    it("returns an error when a file is not a string", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ files = { true } }))
      assert.is_nil(graph)
      assert.are.equal("file at index 1 is wrong type: boolean", err)
    end)

    it("returns an error when a node names a command the graph does not have", function()
      local json = valid_json({ commands = {} })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(graph)
      assert.are.equal("node at index 2: command index out of range: 0", err)
    end)

    it("validates the commands before the files", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ commands = { 42 }, files = { true } }))
      assert.is_nil(graph)
      assert.are.equal("command at index 1 is wrong type: number", err)
    end)

    it("validates the files before the nodes", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ files = { true }, nodes = { "invalid" } }))
      assert.is_nil(graph)
      assert.are.equal("file at index 1 is wrong type: boolean", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a boolean", true },
      { "a string", "install" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a node is %s"):format(label), function()
        local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = 0 }, value } }))
        assert.is_nil(graph)
        assert.are.equal(("node at index 2: is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when the file of a node is missing", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { {} } }))
      assert.is_nil(graph)
      assert.are.equal("node at index 1: file is wrong type: nil", err)
    end)

    it("returns an error when the file of a node is not a number", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = "CMakeLists.txt" } } }))
      assert.is_nil(graph)
      assert.are.equal("node at index 1: file is wrong type: string", err)
    end)

    for _, entry in ipairs({
      { "negative", -1 },
      { "past the end of the files", 2 },
    }) do
      local label, index = entry[1], entry[2]
      it(("returns an error when the file index of a node is %s"):format(label), function()
        local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = index } } }))
        assert.is_nil(graph)
        assert.are.equal(("node at index 1: file index out of range: %d"):format(index), err)
      end)
    end

    it("returns an error when the line of a node is not a number", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = 0, line = "48" } } }))
      assert.is_nil(graph)
      assert.are.equal("node at index 1: line is wrong type: string", err)
    end)

    it("returns an error when the command of a node is not a number", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = 0, command = "install" } } }))
      assert.is_nil(graph)
      assert.are.equal("node at index 1: command is wrong type: string", err)
    end)

    for _, entry in ipairs({
      { "negative", -1 },
      { "past the end of the commands", 1 },
    }) do
      local label, index = entry[1], entry[2]
      it(("returns an error when the command index of a node is %s"):format(label), function()
        local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { { file = 0, command = index } } }))
        assert.is_nil(graph)
        assert.are.equal(("node at index 1: command index out of range: %d"):format(index), err)
      end)
    end

    it("returns an error when the parent of a node is not a number", function()
      local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { valid_node_json({ parent = "0" }) } }))
      assert.is_nil(graph)
      assert.are.equal("node at index 1: parent is wrong type: string", err)
    end)

    for _, entry in ipairs({
      { "negative", -1 },
      { "past the end of the nodes", 2 },
    }) do
      local label, index = entry[1], entry[2]
      it(("returns an error when the parent index of a node is %s"):format(label), function()
        local graph, err = BacktraceGraph.try_from_json(valid_json({ nodes = { valid_node_json({ parent = index }) } }))
        assert.is_nil(graph)
        assert.are.equal(("node at index 1: parent out of range: %d"):format(index), err)
      end)
    end

    it("accepts a node whose parent is a node that comes after it", function()
      local json = valid_json({ nodes = { valid_node_json({ parent = 1 }), { file = 0 } } })

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal(2, assert(graph).nodes[1].parent)
    end)

    it("reports the index of the node it could not parse", function()
      local json = valid_json()
      json.nodes[2].line = "48"

      local graph, err = BacktraceGraph.try_from_json(json)
      assert.is_nil(graph)
      assert.are.equal("node at index 2: line is wrong type: string", err)
    end)
  end)
end)
