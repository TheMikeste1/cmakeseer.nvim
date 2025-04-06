local CmakeseerCallbacks = require("cmakeseer.callbacks")

--- Runs the callbacks for CMakeseer.
---@param component overseer.Component The component being ran.
---@param task overseer.Task The task being ran.
---@return nil|boolean should_run False if the task should NOT be ran.
---@diagnostic disable-next-line: unused-local
local function on_pre_start(component, task)
  vim.notify("Running preconfigure hooks", vim.log.levels.TRACE)
  CmakeseerCallbacks.onPreConfigure()
end

--- @type overseer.Component
return {
  name = "CMakeseer Preconfigure",
  desc = "Run CMakeseer preconfigure hooks",
  editable = false,
  serializable = true,
  params = {},
  --- @return overseer.ComponentSkeleton
  ---@diagnostic disable-next-line: unused-local
  constructor = function(params)
    return {
      on_pre_start = on_pre_start,
    }
  end,
}
