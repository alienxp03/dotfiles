return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>ff",
      "<cmd>Yazi<cr>",
      desc = "Open Yazi at current file",
    },
    {
      "<leader>fF",
      "<cmd>Yazi cwd<cr>",
      desc = "Open Yazi at working directory",
    },
  },
  ---@type YaziConfig
  opts = {
    open_for_directories = false,
    keymaps = {
      show_help = "<f1>",
    },
    set_keymappings_function = function(yazi_buffer_id)
      vim.keymap.set("t", "<Esc>", "<cmd>close<cr>", { buffer = yazi_buffer_id })
    end,
  },
}
