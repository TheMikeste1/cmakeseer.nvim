local M = {}

function M.fetch_presets(dir)
  local presets = {}
  local command = { "cmake", "--list-presets" }
  if dir ~= nil then
    vim.list_extend(command, { "-S", dir })
  end
  local preset_str = vim.system(command):wait().stdout or ""
  for preset in string.gmatch(preset_str, '"([^"]+)"') do
    table.insert(presets, preset)
  end
  return presets
end

return M
