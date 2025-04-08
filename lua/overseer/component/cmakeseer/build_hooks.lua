local Callbacks = require("cmakeseer.callbacks")

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
      ---@diagnostic disable-next-line: unused-local
      on_output_lines = function(self, task, lines)
        for _, line in ipairs(lines) do
          -- This string is printed once configuration is complete
          if line:match("^%-%- Build files have been written to:") then
            Callbacks.on_post_configure_success()
            Callbacks.run_user_postconfigure()
            break
          end
        end
      end,
    }
  end,
}
