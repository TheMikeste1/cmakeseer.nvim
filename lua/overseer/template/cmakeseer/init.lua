return {
  generator = function(search, cb)
    cb({
      require("overseer.template.cmakeseer.cmake_build"),
      require("overseer.template.cmakeseer.cmake_clean"),
      require("overseer.template.cmakeseer.cmake_clean_rebuild"),
      require("overseer.template.cmakeseer.cmake_configure"),
      require("overseer.template.cmakeseer.cmake_configure_fresh"),
      require("overseer.template.cmakeseer.cmake_install"),
    })
  end,
  -- Optional. Same as template.condition
  condition = {
    callback = function(search)
      return vim.fn.filereadable(search.dir .. "CMakeLists.txt") ~= 0
        or require("cmakeseer").is_cmake_project()
    end,
  },
}
