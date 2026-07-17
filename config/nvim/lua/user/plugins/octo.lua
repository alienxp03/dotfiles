return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "folke/snacks.nvim",
  },
  opts = {
    picker = "snacks",
    enable_builtin = true,
    reviews = {
      auto_show_threads = true,
      focus = "right",
    },
    file_panel = {
      size = 14,
      icons = true,
    },
  },
  keys = {
    { "<leader>op", "<cmd>Octo pr list<cr>", desc = "GitHub pull requests" },
    { "<leader>or", "<cmd>Octo review start<cr>", desc = "Start GitHub review" },
  },
}
