local Settings = require("cmakeseer.settings")

local M = {}

--- Creates a list of CMake definitions strings generated from the currents settings.``
--- @return table<string> definitions The definitions.
function M.create_definition_strings()
	local definitions = {}

	for key, value in pairs(Settings.get_settings().configureSettings) do
		local definition = "-D" .. key
		local value_type = type(value)

		-- CMake types are defined in <https://cmake.org/cmake/help/latest/command/set.html#set-cache-entry>
		local good = true
		if value_type == "boolean" then
			definition = definition .. ":BOOL"
		elseif value_type == "number" or value_type == "string" then
			definition = definition .. ":STRING"
		else
			vim.notify(
				"cmake.configureSettings value for `" .. key .. "` is invalid. Skipping definition.",
				vim.log.levels.ERROR
			)
			good = false
		end

		if good then
			definition = definition .. "=" .. tostring(value)
			table.insert(definitions, definition)
		end
	end

	return definitions
end

--- Merges two tables arrays into one, leaving duplicates.
--- @param a table The first table.
--- @param b table The second table
function M.merge_tables(a, b)
	if a == nil then
		return b
	end
	if b == nil then
		return a
	end

	local merged_table = {}
	for _, v in ipairs(a) do
		table.insert(merged_table, v)
	end

	for _, v in ipairs(b) do
		table.insert(merged_table, v)
	end

	return merged_table
end

--- @param kit_files table<string> Paths to files containing CMake kit definitions. These will not be expanded.
--- @return cmakeseer.Kit[] kits The kits
function M.read_cmakekit_files(kit_files)
	assert(kit_files ~= nil, "kit_files must not be nil")

	--- @type cmakeseer.Kit[]
	local kits = {}
	for _, file_path in ipairs(kit_files) do
		if vim.fn.filereadable(file_path) == 0 then
			vim.notify("Kit file `" .. file_path .. "` is not readable. Does it exist?", vim.log.levels.ERROR)
		else
			local file = io.open(file_path, "r")
			if file == nil then
				vim.notify("Unable to read kit file `" .. file_path .. "`", vim.log.levels.ERROR)
			else
				local file_contents = file:read("a")
				file:close()

				local new_kits = vim.json.decode(file_contents)
				M.merge_tables(kits, new_kits)
			end
		end
	end

	return kits
end

return M
