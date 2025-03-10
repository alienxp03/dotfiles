return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    dashboard = {
      enabled = true,
      preset = {
        header = [[
      ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
      ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
      ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
      ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
      ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
      ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
      ]],
      },
      sections = {
        { section = "header" },
      },
    },
    indent = { enabled = true },
    input = { enabled = true },
    lazygit = { configure = true },
    bufdelete = { configure = true },
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
    {
      "<C-q>",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete buffer",
    },
  },
}
