local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local Stateful = require("cmakeseer.cmake.file_api.query.stateful")
local spec_utils = require("spec.utils")
local write_file = spec_utils.write_file
local read_file = spec_utils.read_file

describe("file_api.query", function()
  local tmp = require("spec.fixtures.tmpdir")()
  local client = "cmakeseer"

  ---@return string query_path
  local function get_query_path()
    local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
    return vim.fs.joinpath(query_dir, ("client-%s"):format(client), "query.json")
  end

  ---@return cmakeseer.cmake.file_api.query.Stateful
  local function read_query()
    local contents = read_file(get_query_path())
    return vim.json.decode(contents)
  end

  ---@return string contents
  local function read_raw_query()
    return read_file(get_query_path())
  end

  ---Writes a preexisting query.json, bypassing the API under test.
  ---@param contents string The exact bytes to write.
  local function seed_query(contents)
    write_file(get_query_path(), contents)
  end

  describe("issue_shared_stateless_query", function()
    for key, value in pairs(object_kind.ObjectKindType) do
      it(("creates the correct query for %s"):format(key), function()
        local err = file_api_query.issue_shared_stateless_query(tmp.path, value, 123)
        assert.is_nil(err)
        local expected_path = vim.fs.joinpath(tmp.path, ".cmake", "api", "v1", "query", ("%s-v123"):format(value))
        local stat = vim.uv.fs_stat(expected_path)
        assert.is_not_nil(stat)
        assert.equal("file", assert(stat).type)
      end)
    end

    it("handles directory already existing", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      vim.fs.mkdir(query_dir, { parents = true })

      local err = file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_nil(err)
      local expected_path = vim.fs.joinpath(tmp.path, ".cmake", "api", "v1", "query", ("%s-v123"):format(object_kind.ObjectKindType.Codemodel))
      local stat = vim.uv.fs_stat(expected_path)
      assert.is_not_nil(stat)
      assert.equal("file", assert(stat).type)
    end)

    it("handles directory creation errors", function()
      local file_path = vim.fs.joinpath(tmp.path, "i-am-a-file")
      local f = assert(io.open(file_path, "w"))
      f:close()

      local err = file_api_query.issue_shared_stateless_query(file_path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_not_nil(err)
    end)

    it("handles file creation errors", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      local query_file = ("%s-v%d"):format(object_kind.ObjectKindType.Codemodel, 123)
      local query_path = vim.fs.joinpath(query_dir, query_file)
      vim.fs.mkdir(query_path, { parents = true })

      local err = file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_not_nil(err)
    end)
  end)

  describe("issue_client_stateless_query", function()
    for key, value in pairs(object_kind.ObjectKindType) do
      it(("creates the correct query for %s"):format(key), function()
        local err = file_api_query.issue_client_stateless_query(client, tmp.path, value, 123)
        assert.is_nil(err)
        local expected_path = vim.fs.joinpath(tmp.path, ".cmake", "api", "v1", "query", ("client-%s"):format(client), ("%s-v123"):format(value))
        local stat = vim.uv.fs_stat(expected_path)
        assert.is_not_nil(stat)
        assert.equal("file", assert(stat).type)
      end)
    end

    it("creates the query in a client specific directory", function()
      local err = file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_nil(err)

      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      local client_stat = vim.uv.fs_stat(vim.fs.joinpath(query_dir, ("client-%s"):format(client)))
      assert.is_not_nil(client_stat)
      assert.equal("directory", assert(client_stat).type)

      local shared_stat = vim.uv.fs_stat(vim.fs.joinpath(query_dir, "codemodel-v123"))
      assert.is_nil(shared_stat)
    end)

    it("does not share queries between clients", function()
      local other_client = "cmakeoracle"
      local err = file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_nil(err)
      err = file_api_query.issue_client_stateless_query(other_client, tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_nil(err)

      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      for _, name in ipairs({ client, other_client }) do
        local expected_path = vim.fs.joinpath(query_dir, ("client-%s"):format(name), ("%s-v123"):format(object_kind.ObjectKindType.Codemodel))
        local stat = vim.uv.fs_stat(expected_path)
        assert.is_not_nil(stat)
        assert.equal("file", assert(stat).type)
      end
    end)

    it("handles directory already existing", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      vim.fs.mkdir(vim.fs.joinpath(query_dir, ("client-%s"):format(client)), { parents = true })

      local err = file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_nil(err)
      local expected_path = vim.fs.joinpath(tmp.path, ".cmake", "api", "v1", "query", ("client-%s"):format(client), ("%s-v123"):format(object_kind.ObjectKindType.Codemodel))
      local stat = vim.uv.fs_stat(expected_path)
      assert.is_not_nil(stat)
      assert.equal("file", assert(stat).type)
    end)

    it("handles directory creation errors", function()
      local file_path = vim.fs.joinpath(tmp.path, "i-am-a-file")
      local f = assert(io.open(file_path, "w"))
      f:close()

      local err = file_api_query.issue_client_stateless_query(client, file_path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_not_nil(err)
    end)

    it("handles file creation errors", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      local query_file = ("%s-v%d"):format(object_kind.ObjectKindType.Codemodel, 123)
      local query_path = vim.fs.joinpath(query_dir, ("client-%s"):format(client), query_file)
      vim.fs.mkdir(query_path, { parents = true })

      local err = file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Codemodel, 123)
      assert.is_not_nil(err)
    end)
  end)

  describe("issue_client_stateful_query", function()
    it("creates the query in a client specific directory", function()
      local err = file_api_query.issue_client_stateful_query(client, tmp.path, Stateful.default())
      assert.is_nil(err)

      local stat = vim.uv.fs_stat(get_query_path())
      assert.is_not_nil(stat)
      assert.equal("file", assert(stat).type)
    end)

    it("writes the query as JSON", function()
      local query = Stateful.new({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = { 2, 1 } },
        },
        client = { name = "cmakeseer" },
      })

      local err = file_api_query.issue_client_stateful_query(client, tmp.path, query)
      assert.is_nil(err)
      assert.same(query, read_query())
    end)

    it("replaces any current query", function()
      local err = file_api_query.issue_client_stateful_query(
        client,
        tmp.path,
        Stateful.new({
          requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
        })
      )
      assert.is_nil(err)

      local replacement = Stateful.new({
        requests = { { kind = object_kind.ObjectKindType.Cache, version = 1 } },
      })
      err = file_api_query.issue_client_stateful_query(client, tmp.path, replacement)
      assert.is_nil(err)
      assert.same(replacement, read_query())
    end)

    it("does not share queries between clients", function()
      local other_client = "cmakeoracle"
      local err = file_api_query.issue_client_stateful_query(
        client,
        tmp.path,
        Stateful.new({
          requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
        })
      )
      assert.is_nil(err)
      err = file_api_query.issue_client_stateful_query(
        other_client,
        tmp.path,
        Stateful.new({
          requests = { { kind = object_kind.ObjectKindType.Cache, version = 1 } },
        })
      )
      assert.is_nil(err)

      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      local other_query_path = vim.fs.joinpath(query_dir, ("client-%s"):format(other_client), "query.json")
      local f = assert(io.open(other_query_path, "r"))
      local contents = f:read("*a")
      f:close()
      assert.same({ requests = { { kind = object_kind.ObjectKindType.Cache, version = 1 } } }, vim.json.decode(contents))
    end)

    it("handles directory already existing", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      vim.fs.mkdir(vim.fs.joinpath(query_dir, ("client-%s"):format(client)), { parents = true })

      local err = file_api_query.issue_client_stateful_query(client, tmp.path, Stateful.default())
      assert.is_nil(err)
      assert.same({ requests = {} }, read_query())
    end)

    it("handles directory creation errors", function()
      local file_path = vim.fs.joinpath(tmp.path, "i-am-a-file")
      local f = assert(io.open(file_path, "w"))
      f:close()

      local err = file_api_query.issue_client_stateful_query(client, file_path, Stateful.default())
      assert.is_not_nil(err)
    end)

    it("handles file creation errors", function()
      vim.fs.mkdir(get_query_path(), { parents = true })

      local err = file_api_query.issue_client_stateful_query(client, tmp.path, Stateful.default())
      assert.is_not_nil(err)
    end)
  end)

  describe("add_client_stateful_query", function()
    it("creates the query if it does not exist", function()
      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)
      assert.same({
        requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
      }, read_query())
    end)

    it("appends to an existing query", function()
      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)
      err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Cache,
        version = { 2, 1 },
      })
      assert.is_nil(err)

      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = { 2, 1 } },
        },
      }, read_query())
    end)

    it("preserves request ordering across multiple additions", function()
      local kinds = { object_kind.ObjectKindType.Codemodel, object_kind.ObjectKindType.Cache, object_kind.ObjectKindType.Toolchains }
      for index, kind in ipairs(kinds) do
        local err = file_api_query.add_client_stateful_query(client, tmp.path, { kind = kind, version = index })
        assert.is_nil(err)
      end

      local actual = read_query()
      assert.equal(#kinds, #actual.requests)
      for index, kind in ipairs(kinds) do
        assert.equal(kind, actual.requests[index].kind)
        assert.equal(index, actual.requests[index].version)
      end
    end)

    it("preserves the client field of an existing query", function()
      local err = file_api_query.issue_client_stateful_query(
        client,
        tmp.path,
        Stateful.new({
          requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
          client = { name = "cmakeseer" },
        })
      )
      assert.is_nil(err)

      err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Cache,
        version = 1,
      })
      assert.is_nil(err)

      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = 1 },
        },
        client = { name = "cmakeseer" },
      }, read_query())
    end)

    it("prepends the query when append is false", function()
      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)

      err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Cache,
        version = 1,
      }, { append = false })
      assert.is_nil(err)

      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Cache, version = 1 },
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
        },
      }, read_query())
    end)

    it("appends when append is explicitly true", function()
      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)

      err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Cache,
        version = 1,
      }, { append = true })
      assert.is_nil(err)

      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = 1 },
        },
      }, read_query())
    end)

    it("returns an error and leaves the query untouched when the existing query is malformed", function()
      seed_query("{not json")

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_not_nil(err)
      assert.equal("{not json", read_raw_query())
    end)

    it("returns an error and leaves the query untouched when the existing query is empty", function()
      seed_query("")

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_not_nil(err)
      assert.equal("", read_raw_query())
    end)

    it("creates the request when the existing query omits it", function()
      seed_query(vim.json.encode({ client = { name = "cmakeseer" } }))

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)
      assert.same({
        requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
        client = { name = "cmakeseer" },
      }, read_query())
    end)

    for name, seed in pairs({
      array = "[]",
      ["json null"] = "null",
      number = "42",
      string = '"hello"',
      boolean = "true",
    }) do
      it(("returns an error and leaves the query untouched when the existing query is a JSON %s"):format(name), function()
        seed_query(seed)

        local ok, err = pcall(file_api_query.add_client_stateful_query, client, tmp.path, {
          kind = object_kind.ObjectKindType.Codemodel,
          version = 2,
        })
        assert.is_true(ok)
        assert.is_not_nil(err)
        assert.equal(seed, read_raw_query())
      end)
    end

    for name, request in pairs({
      number = 5,
      string = '"nope"',
      boolean = "true",
    }) do
      it(("returns an error and leaves the query untouched when the existing request is a JSON %s"):format(name), function()
        local seed = vim.json.encode({ requests = request })
        seed_query(seed)

        local ok, err = pcall(file_api_query.add_client_stateful_query, client, tmp.path, {
          kind = object_kind.ObjectKindType.Codemodel,
          version = 2,
        })
        assert.is_true(ok)
        assert.is_not_nil(err)
        assert.equal(seed, read_raw_query())
      end)
    end

    it("truncates the query when the new query is shorter than the existing one", function()
      -- A pretty-printed seed decodes fine but re-encodes to a shorter document.
      seed_query(vim.json.encode({ requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } } }, { indent = "  " }))

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Cache,
        version = 1,
      })
      assert.is_nil(err)
      assert.same({
        requests = {
          { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
          { kind = object_kind.ObjectKindType.Cache, version = 1 },
        },
      }, read_query())
    end)

    it("handles directory already existing", function()
      local query_dir = require("cmakeseer.cmake.file_api").query_dir(tmp.path)
      vim.fs.mkdir(vim.fs.joinpath(query_dir, ("client-%s"):format(client)), { parents = true })

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_nil(err)
      assert.same({
        requests = { { kind = object_kind.ObjectKindType.Codemodel, version = 2 } },
      }, read_query())
    end)

    it("handles directory creation errors", function()
      local file_path = vim.fs.joinpath(tmp.path, "i-am-a-file")
      local f = assert(io.open(file_path, "w"))
      f:close()

      local err = file_api_query.add_client_stateful_query(client, file_path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_not_nil(err)
    end)

    it("handles file creation errors", function()
      vim.fs.mkdir(get_query_path(), { parents = true })

      local err = file_api_query.add_client_stateful_query(client, tmp.path, {
        kind = object_kind.ObjectKindType.Codemodel,
        version = 2,
      })
      assert.is_not_nil(err)
    end)
  end)
end)
