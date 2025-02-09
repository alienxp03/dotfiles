return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    dashboard = {
      enabled = true,
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
        {
          pane = 2,
          icon = " ",
          title = "Git Status",
          section = "terminal",
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
          cmd = "git status --short --branch --renames",
          height = 5,
          padding = 1,
          ttl = 5 * 60,
          indent = 3,
        },
        { section = "startup" },
      },
    },
    indent = { enabled = true },
    input = { enabled = true },
    lazygit = { configure = true },
    win = {
      width = 0.95,
      height = 0.95,
    },
  },
  keys = {
    {
      "<leader>gl",
      function()
        Snacks.lazygit()
      end,
      desc = "Lazygit Current File History",
    },
  },
}
