return {
  "dmtrKovalenko/fff.nvim",
  lazy = false,
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  opts = {
    lazy_sync = true,
    layout = {
      prompt_position = "top",
      preview_position = "bottom",
      flex = {
        size = 130,
        wrap = "bottom",
      },
    },
    keymaps = {
      move_up = { "<Up>", "<C-p>", "<C-k>" },
      move_down = { "<Down>", "<C-n>", "<C-j>" },
    },
  },
  keys = {
    {
      "<leader>ff",
      function()
        require("fff").find_files()
      end,
      desc = "Find files",
    },
    {
      "<leader>fg",
      function()
        require("fff").live_grep()
      end,
      desc = "Live grep",
    },
  },
}
