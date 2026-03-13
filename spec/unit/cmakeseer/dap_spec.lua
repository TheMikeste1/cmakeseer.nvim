local dap_mod = require("cmakeseer.dap")
local CMakeSeer = require("cmakeseer")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.dap", function()
  local dap
  local has_dap

  before_each(function()
    has_dap, dap = pcall(require, "dap")
    if not has_dap then
      -- Mock dap if not available in environment
      dap = {
        adapters = {},
        configurations = {},
        run = function() end,
      }
      package.preload["dap"] = function()
        return dap
      end
      package.preload["dap.ext.vscode"] = function()
        return { type_to_filetypes = {} }
      end
    end
  end)

  after_each(function()
    if not has_dap then
      package.preload["dap"] = nil
      package.preload["dap.ext.vscode"] = nil
    end
  end)

  it("setup registers adapter and configurations", function()
    dap_mod.setup()
    assert.is_not_nil(dap.adapters.cmake)
    assert.is_not_nil(dap.configurations.cmake)

    local config = dap.configurations.cmake[1]
    local get_conf_args_stub = stub(CMakeSeer, "get_configure_args", function()
      return { "-DVAR=VAL" }
    end)
    assert.are.same({ "-DVAR=VAL" }, config.cmakeArgs())

    local config2 = dap.configurations.cmake[2]
    local args2 = config2.cmakeArgs()
    local found_fresh = false
    for _, a in ipairs(args2) do
      if a == "--fresh" then
        found_fresh = true
        break
      end
    end
    assert.is_true(found_fresh)

    get_conf_args_stub:revert()
  end)

  it("debug_configure errors if version unknown", function()
    local get_version_stub = stub(require("cmakeseer.cmake.utils"), "get_cmake_version", function()
      return nil
    end)
    local notify_stub = stub(vim, "notify")

    dap_mod.debug_configure()
    assert.stub(notify_stub).was.called_with("Unable to get CMake version", vim.log.levels.ERROR)

    get_version_stub:revert()
    notify_stub:revert()
  end)

  it("debug_configure errors if dap missing", function()
    local old_package_loaded = package.loaded["dap"]
    package.loaded["dap"] = nil
    local old_require = _G.require
    _G.require = function(mod)
      if mod == "dap" then
        error("not found")
      end
      return old_require(mod)
    end

    local notify_stub = stub(vim, "notify")
    dap_mod.debug_configure()
    assert.stub(notify_stub).was.called_with("nvim-dap not found", vim.log.levels.ERROR)

    _G.require = old_require
    notify_stub:revert()
    package.loaded["dap"] = old_package_loaded
  end)

  it("cmake adapter calls callback with correct config", function()
    dap_mod.setup()
    local adapter = dap.adapters.cmake
    ---@diagnostic disable-next-line: missing-parameter
    local callback_stub = stub()
    local cmake_command_stub = stub(CMakeSeer, "cmake_command", function()
      return "mycmake"
    end)

    local config = {
      cmakeArgs = function()
        return { "-DFOO=BAR" }
      end,
    }

    adapter(callback_stub, config)

    assert.stub(callback_stub).was.called(1)
    local adapter_result = (callback_stub --[[@as any]]).calls[1].refs[1]
    assert.are.equal("pipe", adapter_result.type)
    assert.is_not_nil(adapter_result.pipe)
    assert.are.equal("mycmake", adapter_result.executable.command)

    local found_foo = false
    for _, a in ipairs(adapter_result.executable.args) do
      if a == "-DFOO=BAR" then
        found_foo = true
        break
      end
    end
    assert.is_true(found_foo)

    cmake_command_stub:revert()
  end)

  it("cmake adapter handles nil cmakeArgs", function()
    dap_mod.setup()
    local adapter = dap.adapters.cmake
    ---@diagnostic disable-next-line: missing-parameter
    local callback_stub = stub()
    local cmake_command_stub = stub(CMakeSeer, "cmake_command", function()
      return "mycmake"
    end)

    adapter(callback_stub, {})

    assert.stub(callback_stub).was.called(1)
    local adapter_result = (callback_stub --[[@as any]]).calls[1].refs[1]
    assert.are.equal("mycmake", adapter_result.executable.command)

    cmake_command_stub:revert()
  end)

  describe("debug_configure logic", function()
    local get_version_stub
    local run_stub
    local notify_stub

    before_each(function()
      get_version_stub = stub(require("cmakeseer.cmake.utils"), "get_cmake_version")
      run_stub = stub(dap, "run")
      notify_stub = stub(vim, "notify")
    end)

    after_each(function()
      get_version_stub:revert()
      run_stub:revert()
      notify_stub:revert()
    end)

    it("errors if cmake version too old", function()
      get_version_stub.returns({ major = 3, minor = 20 })
      dap_mod.debug_configure()
      assert.stub(notify_stub).was.called_with(match.matches("required for debugging", 1, true), vim.log.levels.ERROR)
    end)

    it("runs dap if version ok", function()
      get_version_stub.returns({ major = 3, minor = 28 })
      local get_conf_args_stub = stub(CMakeSeer, "get_configure_args", function()
        return { "-DVAR=VAL" }
      end)

      dap_mod.debug_configure(true) -- fresh

      assert.stub(run_stub).was.called(1)
      local run_config = (run_stub --[[@as any]]).calls[1].refs[1]
      assert.are.equal("CMake Debugger", run_config.name)

      local args = run_config.cmakeArgs()
      local found_fresh = false
      for _, a in ipairs(args) do
        if a == "--fresh" then
          found_fresh = true
          break
        end
      end
      assert.is_true(found_fresh)

      get_conf_args_stub:revert()
    end)
  end)
end)
