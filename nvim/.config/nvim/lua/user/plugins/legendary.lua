return {
  "mrjones2014/legendary.nvim",
  version = "v2.1.0",
  priority = 10000,
  lazy = false,
  config = function()
    require("legendary").setup({
      include_builtin = false,
      include_legendary_cmds = false,
      commands = {
        {
          ":CopyRelativePath",
          function()
            local path = vim.fn.expand("%:.")
            vim.fn.setreg("+", path)
          end,
          description = "Copy relative path",
        },
        {
          ":CopyFullPath",
          ':let @+=expand("%:p")',
          description = "Copy full path",
        },
        {
          ":OpenInFinder",
          ":silent !open -R %",
          description = "Open current file in Finder",
        },
        {
          ":OpenInSublime",
          ":silent !subl %",
          description = "Open current file in Sublime Text",
        },
      },
    })
  end,
}
