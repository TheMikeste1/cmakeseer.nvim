local settings = require("cmakeseer.settings")
local config = require("cmakeseer.config")

describe("cmakeseer.settings", function()
  before_each(function()
    settings.reset_settings()
  end)

  it("returns default settings initially", function()
    local default = settings.get_settings()
    assert.are.same(config.default_cmake_settings, default)
  end)

  it("allows setting and getting settings", function()
    local new_settings = {
      configureArgs = { "--extra" },
      configureSettings = { MY_VAR = "value" },
      kit_name = "My Kit",
    }
    settings.set_settings(new_settings)
    assert.are.same(new_settings, settings.get_settings())
  end)

  it("resets settings to defaults", function()
    local new_settings = {
      configureArgs = { "--extra" },
      configureSettings = { MY_VAR = "value" },
      kit_name = "My Kit",
    }
    settings.set_settings(new_settings)
    settings.reset_settings()
    assert.are.same(config.default_cmake_settings, settings.get_settings())
  end)
end)
