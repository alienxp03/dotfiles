return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("gitsigns").setup()

    vim.keymap.set(
      "n",
      "<leader>ge",
      ":Gitsigns toggle_current_line_blame<cr>",
      { noremap = true, silent = true, desc = "Toggle blame" }
    )
    vim.keymap.set(
      "n",
      "<leader>gh",
      ":Gitsigns preview_hunk_inline<cr>",
      { noremap = true, silent = true, desc = "Preview hunk" }
    )
  end,
}
