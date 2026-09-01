local CMakeSeer = require("cmakeseer")
local stub = require("luassert.stub")

describe("plugin cmakeseer", function()
  it("executes plugin script without error", function()
    local load_stub = stub(CMakeSeer, "load_if_configured")
    local dap_setup_stub = stub(require("cmakeseer.dap"), "setup")

    vim.cmd("runtime plugin/cmakeseer.lua")

    assert.stub(load_stub).was.called(1)
    assert.stub(dap_setup_stub).was.called(1)

    load_stub:revert()
    dap_setup_stub:revert()
  end)
end)
