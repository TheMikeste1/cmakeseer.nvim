--- Sets up queries and other tasks for CMakeseer.
---@return nil|boolean should_run False if the task should NOT be ran.
---@diagnostic disable-next-line: unused-local
local function on_pre_start()
  vim.notify("Running prebuild hooks", vim.log.levels.TRACE)
  vim.api.nvim_exec_autocmds("User", { pattern = "CMakeSeerPrebuild" })
end

--- Reads query responses for CMakeseer.
---@param _component overseer.Component The component that was ran.
---@param _task overseer.Task The task that was ran.
---@param status overseer.Status The resulting status from the task.
---@param _result table The table containing results.
---@diagnostic disable-next-line: unused-local
local function on_complete(_component, _task, status, _result)
  vim.notify("Running postbuild hooks", vim.log.levels.TRACE)
  vim.api.nvim_exec_autocmds("User", { pattern = "CMakeSeerPostbuild", data = { status = status } })
end

--- @type overseer.Component
return {
  name = "CMakeseer Build Hooks",
  desc = "Run CMakeseer build hooks",
  editable = false,
  serializable = true,
  params = {},
  --- @return overseer.ComponentSkeleton
  constructor = function()
    return {
      on_pre_start = on_pre_start,
      on_complete = on_complete,
    }
  end,
}
