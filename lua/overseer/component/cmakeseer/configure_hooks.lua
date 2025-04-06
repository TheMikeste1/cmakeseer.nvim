local Callbacks = require("cmakeseer.callbacks")

--- Sets up queries and other tasks for CMakeseer.
---@param component overseer.Component The component being ran.
---@param task overseer.Task The task being ran.
---@return nil|boolean should_run False if the task should NOT be ran.
---@diagnostic disable-next-line: unused-local
local function on_pre_start(component, task)
  vim.notify("Running preconfigure hooks", vim.log.levels.TRACE)
  Callbacks.onPreConfigure()
end

--- Reads query responses for CMakeseer.
---@param component overseer.Component The component that was ran.
---@param task overseer.Task The task that was ran.
---@param status overseer.Status The resulting status from the task.
---@param result table The table containing results.
---@diagnostic disable-next-line: unused-local
local function on_complete(component, task, status, result)
  vim.notify("Running postconfigure hooks", vim.log.levels.TRACE)
  if status == "SUCCESS" then
    Callbacks.onPostConfigureSuccess()
  end
end

--- @type overseer.Component
return {
  name = "CMakeseer Configure Hooks",
  desc = "Run CMakeseer configure hooks",
  editable = false,
  serializable = true,
  params = {},
  --- @return overseer.ComponentSkeleton
  ---@diagnostic disable-next-line: unused-local
  constructor = function(params)
    return {
      on_pre_start = on_pre_start,
      on_complete = on_complete,
    }
  end,
}
