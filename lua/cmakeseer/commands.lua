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
  }, function(kit)
    CMakeSeer.state.selections.kit = kit
  end)
end

--- Select a preset to use
function M.select_preset()
  local presets = require("cmakeseer.cmake.preset").fetch_presets(require("cmakeseer").get_config():get_project_root())
  table.insert(presets, "<none>")
  vim.ui.select(presets, {
    prompt = "Select preset",
  }, function(preset)
    if preset == "<none>" then
      preset = nil
    end
    CMakeSeer.state.selections.preset = preset
  end)
end

function M.select_variant()
  local variants = {}
  for _, value in pairs(CMakeSeer.Variant) do
    table.insert(variants, value)
  end

  vim.ui.select(variants, {
    prompt = "Select variant",
  }, function(variant)
    if variant == nil then
      return
    end
    CMakeSeer.state.selections.variant = variant
  end)
end

return M
