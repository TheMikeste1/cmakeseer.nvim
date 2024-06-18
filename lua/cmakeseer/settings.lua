local M = {}

---@class CMakeSettings
---@field configureSettings table<string, string|boolean|number> Contains the definition:value pairs to be used when configuring the project.

--- @return CMakeSettings default_settings The default settings to use.
function M.get_default_settings()
	return {
		configureSettings = {},
	}
end

---@type CMakeSettings
M.settings = M.get_default_settings()

return M
