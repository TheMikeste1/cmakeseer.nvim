local CMakeSeer = require("cmakeseer")

local M = {}

-- TODO: Allow passing a selection directly to the function

--- Select a kit to use
function M.select_kit()
  local kits = CMakeSeer.get_all_kits()
  vim.ui.select(kits, {
    prompt = "Select kit",
    --- @param item cmakeseer.Kit
    --- @return string
    format_item = function(item)
      local c_compiler = item.compilers.C
      if #c_compiler > 20 then
        c_compiler = vim.fn.pathshorten(c_compiler)
      end

      local cxx_compiler = item.compilers.CXX
      if cxx_compiler == nil then
        cxx_compiler = "<no CXX compiler>"
      end
      if #cxx_compiler > 20 then
        cxx_compiler = vim.fn.pathshorten(cxx_compiler)
      end
      return item.name .. " (" .. c_compiler .. ", " .. cxx_compiler .. ")"
    end,
  }, CMakeSeer.state.set_selected_kit)
end

--- Select a preset to use
function M.select_preset()
  local presets = require("cmakeseer.cmake").fetch_presets()
  table.insert(presets, "<none>")
  vim.ui.select(presets, {
    prompt = "Select preset",
  }, function(preset)
    if preset == "<none>" then
      preset = nil
    end
    CMakeSeer.state.set_selected_preset(preset)
  end)
end

function M.clear_preset()
  local presets = require("cmakeseer.cmake").fetch_presets()
  vim.ui.select(presets, {
    prompt = "Select preset",
  }, CMakeSeer.state.set_selected_preset)
end

function M.select_variant()
  local variants = {}
  for _, value in pairs(CMakeSeer.Variant) do
    table.insert(variants, value)
  end

  vim.ui.select(variants, {
    prompt = "Select variant",
  }, CMakeSeer.state.set_selected_variant)
end

return M
