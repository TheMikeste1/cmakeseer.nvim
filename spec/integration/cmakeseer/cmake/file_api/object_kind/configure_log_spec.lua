local ConfigureLog = require("cmakeseer.cmake.file_api.object_kind.configure_log")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local read_file = require("spec.utils").read_file

--- The path of the configureLog object file written by the last configure.
---@param build_dir string
---@return string? path
local function configure_log_object_path(build_dir)
  local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "configureLog-*.json")
  local matches = vim.fn.glob(pattern, true, true)
  return matches[1]
end

--- Configures the `object_kinds` project with a configureLog query issued.
---@param build_dir string
local function configure_with_configure_log_query(build_dir)
  assert.is_nil(file_api_query.issue_shared_stateless_query(build_dir, object_kind.ObjectKindType.ConfigureLog, 1))
  cmake_configure("object_kinds", build_dir)
end

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
  local tmp = require("spec.fixtures.tmpdir")()

  describe("try_from_file", function()
    it("parses the configureLog object CMake writes", function()
      configure_with_configure_log_query(tmp.path)
      local path = configure_log_object_path(tmp.path)
      assert.is_not_nil(path)

      local configure_log, err = ConfigureLog.try_from_file(assert(path))
      assert.is_nil(err)
      local instance = assert(configure_log)
      assert.are.equal(object_kind.ObjectKindType.ConfigureLog, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.equal(vim.fs.joinpath(tmp.path, "CMakeFiles", "CMakeConfigureLog.yaml"), instance.path)
    end)

    -- The fixture only guarantees the `message` event. The other event kinds depend on how CMake
    -- detects the toolchain, so assert the shape rather than CMake's exact detection output.
    it("records the message event the fixture emits", function()
      configure_with_configure_log_query(tmp.path)
      local path = configure_log_object_path(tmp.path)
      assert.is_not_nil(path)

      local configure_log = assert(ConfigureLog.try_from_file(assert(path)))
      assert.is_true(has_event_kind(configure_log.event_kinds, ConfigureLog.EventKind.Message, 1))
    end)

    it("records only known event kinds", function()
      configure_with_configure_log_query(tmp.path)
      local path = configure_log_object_path(tmp.path)
      assert.is_not_nil(path)

      local configure_log = assert(ConfigureLog.try_from_file(assert(path)))
      local known_kinds = vim.tbl_values(ConfigureLog.EventKind)
      for _, event_kind in ipairs(configure_log.event_kinds) do
        assert.is_true(vim.tbl_contains(known_kinds, event_kind.kind))
        assert.is_true(event_kind.version > 0)
      end
    end)

    it("points at a configure log holding the project message", function()
      configure_with_configure_log_query(tmp.path)
      local path = configure_log_object_path(tmp.path)
      assert.is_not_nil(path)

      local configure_log = assert(ConfigureLog.try_from_file(assert(path)))
      assert.are.equal(1, vim.fn.filereadable(configure_log.path))
      assert.is_not_nil(read_file(configure_log.path):find("CMAKESEER_CONFIGURE_LOG_MARKER", 1, true))
    end)
  end)
end)
