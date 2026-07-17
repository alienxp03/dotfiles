return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("gitsigns").setup()

    local blame_command = ":Git blame --date=format:\\%-d\\ \\%b\\ \\%Y\\ \\%I:\\%M\\ \\%p\\ \\%z<cr>"
    vim.keymap.set("n", "<leader>ge", blame_command, { noremap = true, silent = true, desc = "Blame current file" })
    vim.keymap.set("x", "<leader>ge", blame_command, { noremap = true, silent = true, desc = "Blame selected lines" })
    vim.keymap.set(
      "n",
      "<leader>gh",
      ":Gitsigns preview_hunk_inline<cr>",
      { noremap = true, silent = true, desc = "Preview hunk" }
    )
  end,
}
