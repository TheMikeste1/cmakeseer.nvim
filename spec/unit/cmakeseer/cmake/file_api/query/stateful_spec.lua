local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local Stateful = require("cmakeseer.cmake.file_api.query.stateful")
local spec_utils = require("spec.utils")
local write_file = spec_utils.write_file
local read_file = spec_utils.read_file

describe("file_api.query.Stateful", function()
  ---@type string
  local tmp_dir
  before_each(function()
    tmp_dir = require("spec.utils").make_tmp_dir()
  end)
  after_each(function()
    spec_utils.delete_dir(tmp_dir)
  end)

  ---@param name string The file name within the temporary directory.
  ---@return string path
  local function tmp_path(name)
    return vim.fs.joinpath(tmp_dir, name)
  end

  describe("new", function()
    it("defaults request to an empty list", function()
      local query = Stateful.new()
      assert.same({}, query.requests)
    end)

    it("preserves the provided request", function()
      local requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } }
      local query = Stateful.new({ requests = requests })
      assert.same(requests, query.requests)
    end)

    it("preserves the optional client", function()
      local query = Stateful.new({ requests = {}, client = { name = "cmakeseer" } })
      assert.same({ name = "cmakeseer" }, query.client)
    end)

    it("does not share the provided request with the instance", function()
      local requests = {}
      local query = Stateful.new({ requests = requests })
      table.insert(requests, { kind = object_kind.ObjectKindType.Cache, version = 1 })
      assert.same({}, query.requests)
    end)
  end)

  describe("default", function()
    it("creates a query with an empty request", function()
      local query = Stateful.default()
      assert.same({}, query.requests)
    end)

    it("does not share the request between instances", function()
      local query = Stateful.default()
      local other = Stateful.default()
      table.insert(query.requests, { kind = object_kind.ObjectKindType.Cache, version = 1 })
      assert.same({}, other.requests)
    end)
  end)

  describe("add_request", function()
    it("adds a request", function()
      local query = Stateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Cache, version = 1 })
      assert.same({ { kind = object_kind.ObjectKindType.Cache, version = 1 } }, query.requests)
    end)
  end)

  describe("to_file", function()
    it("writes the query as JSON", function()
      local path = tmp_path("query.json")
      local query = Stateful.new({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = { 2, 1 } },
        },
        client = { name = "cmakeseer" },
      })

      assert.is_nil(query:to_file(path))
      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = { 2, 1 } },
        },
        client = { name = "cmakeseer" },
      }, vim.json.decode(read_file(path)))
    end)

    it("overwrites an existing file", function()
      local path = tmp_path("query.json")
      write_file(path, vim.json.encode({ requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } } }))

      local query = Stateful.default()
      assert.is_nil(query:to_file(path))
      assert.same({ requests = {} }, vim.json.decode(read_file(path)))
    end)

    it("returns an error when the path cannot be written", function()
      local path = tmp_path("i-am-a-directory")
      vim.fs.mkdir(path, { parents = true })

      local err = Stateful.default():to_file(path)
      assert.is_not_nil(err)
    end)
  end)

  describe("from_file", function()
    it("reads a query written by to_file", function()
      local path = tmp_path("query.json")
      local expected = Stateful.new({
        requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
        client = { name = "cmakeseer" },
      })
      assert.is_nil(expected:to_file(path))

      local actual, err = Stateful.from_file(path)
      assert.is_nil(err)
      assert.same(expected, actual)
    end)

    it("returns a query that can be written back", function()
      local path = tmp_path("query.json")
      assert.is_nil(Stateful.new({ requests = {} }):to_file(path))

      local query = assert(Stateful.from_file(path))
      assert.is_function(query.to_file)
      assert.is_nil(query:to_file(path))
    end)

    it("defaults a missing request to an empty list", function()
      local path = tmp_path("query.json")
      write_file(path, vim.json.encode({ client = { name = "cmakeseer" } }))

      local query, err = Stateful.from_file(path)
      assert.is_nil(err)
      assert.same({ requests = {}, client = { name = "cmakeseer" } }, query)
    end)

    it("ignores surrounding whitespace", function()
      local path = tmp_path("query.json")
      write_file(path, ("\n  %s  \n"):format(vim.json.encode({ requests = {} })))

      local query, err = Stateful.from_file(path)
      assert.is_nil(err)
      assert.same({ requests = {} }, query)
    end)

    it("returns an error when the file does not exist", function()
      local query, err = Stateful.from_file(tmp_path("query.json"))
      assert.is_nil(query)
      assert.is_not_nil(err)
    end)

    it("returns an error when the path is a directory", function()
      local path = tmp_path("i-am-a-directory")
      vim.fs.mkdir(path, { parents = true })

      local query, err = Stateful.from_file(path)
      assert.is_nil(query)
      assert.is_not_nil(err)
    end)

    it("returns an error for an empty file", function()
      local path = tmp_path("query.json")
      write_file(path, "")

      local query, err = Stateful.from_file(path)
      assert.is_nil(query)
      assert.is_not_nil(err)
    end)

    it("returns an error for malformed JSON", function()
      local path = tmp_path("query.json")
      write_file(path, "{not json")

      local query, err = Stateful.from_file(path)
      assert.is_nil(query)
      assert.is_not_nil(err)
    end)

    for name, contents in pairs({
      array = "[]",
      ["json null"] = "null",
      number = "42",
      string = '"hello"',
      boolean = "true",
    }) do
      it(("returns an error when the file contains a JSON %s"):format(name), function()
        local path = tmp_path("query.json")
        write_file(path, contents)

        local query, err = Stateful.from_file(path)
        assert.is_nil(query)
        assert.is_not_nil(err)
      end)
    end

    for name, request in pairs({
      number = 5,
      string = '"nope"',
      boolean = "true",
    }) do
      it(("returns an error when the request is a JSON %s"):format(name), function()
        local path = tmp_path("query.json")
        write_file(path, vim.json.encode({ requests = request }))

        local query, err = Stateful.from_file(path)
        assert.is_nil(query)
        assert.is_not_nil(err)
      end)
    end
  end)
end)
