---@module "nui"

local function jump_to(target_popup)
  if target_popup.winid then
    vim.api.nvim_set_current_win(target_popup.winid)
  end
end

local function make_quit(layout)
  return function()
    layout:unmount()
  end
end

--- Makes the form submit handler.
---@param variable_field NuiPopup The popup for the variable name.
---@param value_field NuiPopup The popup for the variable value.
---@param fn_quit function() The quit function.
---@return function on_submit
local function make_on_submit(variable_field, value_field, fn_quit)
  return function()
    local variable_name = table.concat(vim.api.nvim_buf_get_lines(variable_field.bufnr, 0, -1, false))
    variable_name = vim.trim(variable_name)
    if #variable_name == 0 then
      return
    end

    local variable_value = table.concat(vim.api.nvim_buf_get_lines(value_field.bufnr, 0, -1, false))

    local Settings = require("cmakeseer.settings")
    local settings = Settings.get_settings()
    settings.configureSettings[variable_name] = variable_value
    Settings.set_settings(settings)

    fn_quit()
  end
end

return function()
  local Popup = require("nui.popup")
  local Layout = require("nui.layout")

  local variable_field = Popup({
    enter = true,
    border = { style = "rounded", text = { top = "Variable" } },
  })
  local value_field = Popup({
    border = { style = "rounded", text = { top = "Value" } },
  })

  local layout = Layout(
    {
      relative = "editor",
      position = "50%",
      size = { width = 60, height = 3 },
    },
    Layout.Box({
      Layout.Box(variable_field, { grow = 1 }),
      Layout.Box(value_field, { grow = 1 }),
    }, { dir = "col" })
  )

  -- Keymaps to switch focus
  variable_field:map("n", "<Tab>", function()
    jump_to(value_field)
  end)
  value_field:map("n", "<Tab>", function()
    jump_to(variable_field)
  end)

  local quit = make_quit(layout)
  local on_submit = make_on_submit(variable_field, value_field, quit)
  vim
    .iter({
      variable_field,
      value_field,
    })
    :each(function(field)
      field:map("n", "q", quit)
      field:map("n", "<CR>", on_submit)
    end)

  layout:mount()
end
