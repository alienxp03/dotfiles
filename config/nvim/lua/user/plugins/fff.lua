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
      preview_position = "right",
      flex = {
        size = 130,
        wrap = "bottom",
      },
    },
    hl = {
      directory_path = "SnacksPickerDir",
    },
    keymaps = {
      move_up = { "<Up>", "<C-p>", "<C-k>" },
      move_down = { "<Down>", "<C-n>", "<C-j>" },
    },
  },
  keys = {
    {
      "<leader>fg",
      function()
        require("fff").live_grep()
      end,
      desc = "Live grep",
    },
  },
}
