local ConfigureLog = require("cmakeseer.cmake.file_api.object_kind.configure_log")
local configured_build = require("spec.fixtures.configured_build")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local read_file = require("spec.utils").read_file

--- Whether the event kinds contain an entry with the given kind and version.
---@param event_kinds cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind[]
---@param kind cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKindType
---@param version number
---@return boolean
local function has_event_kind(event_kinds, kind, version)
  for _, event_kind in ipairs(event_kinds) do
    if event_kind.kind == kind and event_kind.version == version then
      return true
    end
  end
  return false
end

describe("object_kind.ConfigureLog", function()
  --- The path of the configureLog object file CMake wrote into the build directory.
  ---@type string
  local object_path

  --- The build directory CMake configured, which the configure log lives in.
  ---@type string
  local build_dir

  lazy_setup(function()
    build_dir = configured_build.of_project("object_kinds", function(dir)
      assert.is_nil(file_api_query.issue_shared_stateless_query(dir, object_kind.ObjectKindType.ConfigureLog, 1))
    end)

    local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "configureLog-*.json")
    object_path = assert(vim.fn.glob(pattern, true, true)[1])
  end)

  describe("try_from_file", function()
    it("parses the configureLog object CMake writes", function()
      local configure_log, err = ConfigureLog.try_from_file(object_path)
      assert.is_nil(err)
      local instance = assert(configure_log)
      assert.are.equal(object_kind.ObjectKindType.ConfigureLog, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.equal(vim.fs.joinpath(build_dir, "CMakeFiles", "CMakeConfigureLog.yaml"), instance.path)
    end)

    -- The fixture only guarantees the `message` event. The other event kinds depend on how CMake
    -- detects the toolchain, so assert the shape rather than CMake's exact detection output.
    it("records the message event the fixture emits", function()
      local configure_log = assert(ConfigureLog.try_from_file(object_path))
      assert.is_true(has_event_kind(configure_log.event_kinds, ConfigureLog.EventKind.Message, 1))
    end)

    it("records only known event kinds", function()
      local configure_log = assert(ConfigureLog.try_from_file(object_path))
      local known_kinds = vim.tbl_values(ConfigureLog.EventKind)
      for _, event_kind in ipairs(configure_log.event_kinds) do
        assert.is_true(vim.tbl_contains(known_kinds, event_kind.kind))
        assert.is_true(event_kind.version > 0)
      end
    end)

    it("points at a configure log holding the project message", function()
      local configure_log = assert(ConfigureLog.try_from_file(object_path))
      assert.are.equal(1, vim.fn.filereadable(configure_log.path))
      assert.is_not_nil(read_file(configure_log.path):find("CMAKESEER_CONFIGURE_LOG_MARKER", 1, true))
    end)
  end)
end)
