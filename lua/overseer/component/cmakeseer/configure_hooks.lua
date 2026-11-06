local Callbacks = require("cmakeseer.callbacks")

--- Resolves the build directories the hooks should act on.
---@param build_dirs? string[] The build directories to use, if any.
---@return string[] build_dirs The build directories to use, defaulting to CMakeSeer's resolved build directory.
local function resolve_build_dirs(build_dirs)
  if build_dirs == nil or vim.tbl_isempty(build_dirs) then
    return { require("cmakeseer").resolve_build_directory() }
  end

  -- Preserve the order, but only issue each hook once per directory.
  return vim.iter(build_dirs):unique():totable()
end

--- @type overseer.Component
return {
  name = "CMakeseer Configure Hooks",
  desc = "Run CMakeseer configure hooks",
  editable = false,
  serializable = true,
  params = {
    build_dirs = {
      desc = "The build directories to run the hooks against. Defaults to CMakeSeer's resolved build directory.",
      type = "list",
      subtype = {
        type = "string",
      },
      optional = true,
    },
  },
  --- @param params { build_dirs?: string[] } The parameters for the component.
  --- @return overseer.ComponentSkeleton
  constructor = function(params)
    local build_dirs = resolve_build_dirs(params.build_dirs)
    ---@return nil|boolean should_run False if the task should NOT be ran.
    ---@diagnostic disable-next-line: unused-local
    local function on_pre_start()
      vim.notify("Running preconfigure hooks", vim.log.levels.TRACE)
      for _, build_dir in ipairs(build_dirs) do
        Callbacks.on_pre_configure(build_dir)
      end
      vim.api.nvim_exec_autocmds("User", { pattern = "CMakeSeerPreconfigure" })
    end

    --- Reads query responses for CMakeseer.
    ---@param _component overseer.Component The component that was ran.
    ---@param _task overseer.Task The task that was ran.
    ---@param status overseer.Status The resulting status from the task.
    ---@param _result table The table containing results.
    ---@diagnostic disable-next-line: unused-local
    local function on_complete(_component, _task, status, _result)
      vim.notify("Running postconfigure hooks", vim.log.levels.TRACE)
      if status == "SUCCESS" then
        for _, build_dir in ipairs(build_dirs) do
          Callbacks.on_post_configure_success(build_dir)
        end
      end
      vim.api.nvim_exec_autocmds("User", { pattern = "CMakeSeerPostconfigure", data = { status = status } })
    end

    return {
      on_pre_start = on_pre_start,
      on_complete = on_complete,
    }
  end,
}
