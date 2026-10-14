local file_api = require("cmakeseer.cmake.file_api")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

describe("file_api", function()
  describe("query_dir", function()
    it("returns the correct path", function()
      local result = file_api.query_dir(".")
      assert.are.equal("./.cmake/api/v1/query", result)
    end)
  end)
  describe("reply_dir", function()
    it("returns the correct path", function()
      local result = file_api.reply_dir(".")
      assert.are.equal("./.cmake/api/v1/reply", result)
    end)
  end)
  describe("build_stateless_id", function()
    for key, kind in pairs(object_kind.ObjectKindType) do
      it(("builds the id of the %s object kind"):format(key), function()
        assert.are.equal(("%s-v1"):format(kind), file_api.build_stateless_id(kind, 1))
      end)
    end

    for _, version in ipairs({ 0, 1, 2, 10 }) do
      it(("includes major version %d in the id"):format(version), function()
        assert.are.equal(("codemodel-v%d"):format(version), file_api.build_stateless_id(object_kind.ObjectKindType.Codemodel, version))
      end)
    end
  end)
  describe("build_client_id", function()
    for _, name in ipairs({ "cmakeseer", "another-client", "client-cmakeseer", "A_client_0" }) do
      it(("prefixes the client name %q"):format(name), function()
        assert.are.equal("client-" .. name, file_api.build_client_id(name))
      end)
    end
  end)
end)
