local ConfigureLog = require("cmakeseer.cmake.file_api.object_kind.configure_log")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local tmpdir = require("spec.fixtures.tmpdir")

---A valid configureLog object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "configureLog",
    version = { major = 1, minor = 0 },
    path = "/tmp/build/CMakeFiles/CMakeConfigureLog.yaml",
    eventKindNames = { "message-v1", "try_compile-v1", "try_run-v1", "find-v1", "find_package-v1" },
  }, overrides or {})
end

---The event kinds CMake writes, as parsed from their names.
---@return cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind[]
local function valid_event_kinds()
  return {
    { kind = ConfigureLog.EventKind.Message, version = 1 },
    { kind = ConfigureLog.EventKind.TryCompile, version = 1 },
    { kind = ConfigureLog.EventKind.TryRun, version = 1 },
    { kind = ConfigureLog.EventKind.Find, version = 1 },
    { kind = ConfigureLog.EventKind.FindPackage, version = 1 },
  }
end

---A valid configureLog object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

---A valid configureLog object with a single version field removed.
---@param field string The version field to remove.
---@return table<string, any> json
local function json_without_version_field(field)
  local json = valid_json()
  json.version[field] = nil
  return json
end

describe("ConfigureLog", function()
  local tmp = tmpdir()

  describe("EventKind", function()
    it("Message value matches the CMake docs", function()
      assert.are.equal("message", ConfigureLog.EventKind.Message)
    end)
    it("TryCompile value matches the CMake docs", function()
      assert.are.equal("try_compile", ConfigureLog.EventKind.TryCompile)
    end)
    it("TryRun value matches the CMake docs", function()
      assert.are.equal("try_run", ConfigureLog.EventKind.TryRun)
    end)
    it("Find value matches the CMake docs", function()
      assert.are.equal("find", ConfigureLog.EventKind.Find)
    end)
    it("FindPackage value matches the CMake docs", function()
      assert.are.equal("find_package", ConfigureLog.EventKind.FindPackage)
    end)
  end)

  describe("new", function()
    it("initializes correctly", function()
      local event_kinds = valid_event_kinds()
      local configure_log = ConfigureLog.new({ major = 1, minor = 0 }, "/tmp/log.yaml", event_kinds)
      assert.are.equal(object_kind.ObjectKindType.ConfigureLog, configure_log.kind)
      assert.are.equal(1, configure_log.version.major)
      assert.are.equal(0, configure_log.version.minor)
      assert.are.equal("/tmp/log.yaml", configure_log.path)
      assert.are.same(valid_event_kinds(), configure_log.event_kinds)
    end)

    it("does not share the version or event kinds with the caller", function()
      local version = { major = 1, minor = 0 }
      local event_kinds = valid_event_kinds()

      local configure_log = ConfigureLog.new(version, "/tmp/log.yaml", event_kinds)
      version.major = 9
      event_kinds[1].version = 9

      assert.are.equal(1, configure_log.version.major)
      assert.are.same(valid_event_kinds(), configure_log.event_kinds)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local configure_log, err = ConfigureLog.try_from_json(value)
        assert.is_nil(configure_log)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json())
      assert.is_nil(err)
      local instance = assert(configure_log)
      assert.are.equal(object_kind.ObjectKindType.ConfigureLog, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.equal("/tmp/build/CMakeFiles/CMakeConfigureLog.yaml", instance.path)
      assert.are.same(valid_event_kinds(), instance.event_kinds)
    end)

    it("does not share the version table with the json", function()
      local json = valid_json()
      local configure_log = assert(ConfigureLog.try_from_json(json))
      json.version.major = 9
      assert.are.equal(1, configure_log.version.major)
    end)

    it("accepts an empty list of event kinds", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(configure_log).event_kinds)
    end)

    for _, entry in ipairs({
      { "message", ConfigureLog.EventKind.Message },
      { "try_compile", ConfigureLog.EventKind.TryCompile },
      { "try_run", ConfigureLog.EventKind.TryRun },
      { "find", ConfigureLog.EventKind.Find },
      { "find_package", ConfigureLog.EventKind.FindPackage },
    }) do
      local name, expected_kind = entry[1], entry[2]
      it(("parses %q into a kind and version"):format(name .. "-v1"), function()
        local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { name .. "-v1" } }))
        assert.is_nil(err)
        assert.are.same({ { kind = expected_kind, version = 1 } }, assert(configure_log).event_kinds)
      end)

      it(("parses a version other than 1 for %q"):format(name), function()
        local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { name .. "-v42" } }))
        assert.is_nil(err)
        assert.are.same({ { kind = expected_kind, version = 42 } }, assert(configure_log).event_kinds)
      end)
    end

    -- "find" is a prefix of "find_package", so a naive match would file find_package-v1 under "find".
    it("does not confuse find_package with find", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { "find_package-v1" } }))
      assert.is_nil(err)
      assert.are.same({ { kind = ConfigureLog.EventKind.FindPackage, version = 1 } }, assert(configure_log).event_kinds)
    end)

    it("preserves the order of the event kinds", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { "find_package-v1", "message-v1", "find-v1" } }))
      assert.is_nil(err)
      assert.are.same({
        { kind = ConfigureLog.EventKind.FindPackage, version = 1 },
        { kind = ConfigureLog.EventKind.Message, version = 1 },
        { kind = ConfigureLog.EventKind.Find, version = 1 },
      }, assert(configure_log).event_kinds)
    end)

    for _, entry in ipairs({
      { "a bare kind name without a version", "message" },
      { "an empty version", "message-v" },
      { "a version with trailing text", "message-v1extra" },
      { "an unknown kind", "bogus-v1" },
      { "a kind name used as a prefix of the version", "message-vmessage-v1" },
      { "an empty string", "" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error for %s"):format(label), function()
        local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { value } }))
        assert.is_nil(configure_log)
        assert.are.equal(("Invalid event kind at index 1: %s"):format(value), err)
      end)
    end

    it("reports the index of the invalid event kind", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { "message-v1", "try_run-v1", "bogus-v1" } }))
      assert.is_nil(configure_log)
      assert.are.equal("Invalid event kind at index 3: bogus-v1", err)
    end)

    it("ignores unknown top-level fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local configure_log, err = ConfigureLog.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(configure_log), "futureField"))
    end)

    it("returns an error when the kind is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without("kind"))
      assert.is_nil(configure_log)
      assert.are.equal("Incorrect kind: nil", err)
    end)

    it("returns an error when the kind is a different object kind", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ kind = "codemodel" }))
      assert.is_nil(configure_log)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)

    it("returns an error when version is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without("version"))
      assert.is_nil(configure_log)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ version = 1 }))
      assert.is_nil(configure_log)
      assert.are.equal("version is wrong type: number", err)
    end)

    it("returns an error when version.major is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without_version_field("major"))
      assert.is_nil(configure_log)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns an error when version.major is not a number", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ version = { major = "1", minor = 0 } }))
      assert.is_nil(configure_log)
      assert.are.equal("version.major is wrong type: string", err)
    end)

    it("returns an error when version.minor is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without_version_field("minor"))
      assert.is_nil(configure_log)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("returns an error when version.minor is not a number", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ version = { major = 1, minor = "0" } }))
      assert.is_nil(configure_log)
      assert.are.equal("version.minor is wrong type: string", err)
    end)

    it("returns an error when path is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without("path"))
      assert.is_nil(configure_log)
      assert.are.equal("path is wrong type: nil", err)
    end)

    it("returns an error when path is not a string", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ path = 42 }))
      assert.is_nil(configure_log)
      assert.are.equal("path is wrong type: number", err)
    end)

    it("returns an error when eventKindNames is missing", function()
      local configure_log, err = ConfigureLog.try_from_json(json_without("eventKindNames"))
      assert.is_nil(configure_log)
      assert.are.equal("eventKindNames is wrong type: nil", err)
    end)

    it("returns an error when eventKindNames is not a list", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = "message-v1" }))
      assert.is_nil(configure_log)
      assert.are.equal("eventKindNames is wrong type: string", err)
    end)

    it("returns an error when eventKindNames is a dict instead of a list", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { message = "message-v1" } }))
      assert.is_nil(configure_log)
      assert.are.equal("eventKindNames is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "table", {} },
      { "null", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when an event kind is a %s"):format(label), function()
        local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { value } }))
        assert.is_nil(configure_log)
        assert.are.equal(("Invalid event kind at index 1: %s"):format(vim.inspect(value)), err)
      end)
    end

    it("reports the index of a non-string event kind", function()
      local configure_log, err = ConfigureLog.try_from_json(valid_json({ eventKindNames = { "message-v1", 42 } }))
      assert.is_nil(configure_log)
      assert.are.equal("Invalid event kind at index 2: 42", err)
    end)
  end)

  describe("try_from_file", function()
    --- Writes JSON to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "configureLog-v1-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("creates an instance from a valid file", function()
      local path = write(vim.json.encode(valid_json()))

      local configure_log, err = ConfigureLog.try_from_file(path)
      assert.is_nil(err)
      local instance = assert(configure_log)
      assert.are.equal(object_kind.ObjectKindType.ConfigureLog, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.equal("/tmp/build/CMakeFiles/CMakeConfigureLog.yaml", instance.path)
      assert.are.same(valid_event_kinds(), instance.event_kinds)
    end)

    it("returns the event kind error of the file it could not parse", function()
      local json = vim.json.encode(valid_json({ eventKindNames = { "bogus-v1" } }))

      local configure_log, err = ConfigureLog.try_from_file(write(json))
      assert.is_nil(configure_log)
      assert.are.equal("Invalid event kind at index 1: bogus-v1", err)
    end)

    for _, entry in ipairs({
      { "the first", { vim.NIL, "try_compile-v1" } },
      { "a later one", { "message-v1", vim.NIL, "try_compile-v1" } },
    }) do
      local label, event_kind_names = entry[1], entry[2]
      it(("returns an error when the json writes null as %s event kind name"):format(label), function()
        local json = vim.json.encode(valid_json({ eventKindNames = event_kind_names }))

        local configure_log, err = ConfigureLog.try_from_file(write(json))
        assert.is_nil(configure_log)
        assert.is_not_nil(err)
      end)
    end

    -- A trailing null leaves no hole, so the list stays a list and the log parses without that entry.
    it("leaves out the event kind name the json writes as a trailing null", function()
      local json = vim.json.encode(valid_json({ eventKindNames = { "message-v1", vim.NIL } }))

      local configure_log, err = ConfigureLog.try_from_file(write(json))
      assert.is_nil(err)
      assert.are.same({ { kind = ConfigureLog.EventKind.Message, version = 1 } }, assert(configure_log).event_kinds)
    end)

    it("returns an error when the file does not exist", function()
      local configure_log, err = ConfigureLog.try_from_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(configure_log)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local configure_log, err = ConfigureLog.try_from_file(dir)
      assert.is_nil(configure_log)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is not JSON", function()
      local configure_log, err = ConfigureLog.try_from_file(write("not json"))
      assert.is_nil(configure_log)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the JSON does not describe a configureLog", function()
      local configure_log, err = ConfigureLog.try_from_file(write(vim.json.encode(valid_json({ kind = "codemodel" }))))
      assert.is_nil(configure_log)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)
  end)
end)
