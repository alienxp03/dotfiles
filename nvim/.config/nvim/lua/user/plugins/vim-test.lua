return {
  "vim-test/vim-test",
  event = "VeryLazy",
  dependencies = {
    "preservim/vimux",
  },
  config = function()
    vim.cmd("let test#strategy = 'vimux'")

    vim.g["test#go#gotest#options"] = {
      nearest = "-v",
      file = "-v",
    }
    vim.g["test#go#runner"] = "richgo"

    vim.api.nvim_set_keymap("n", "<leader>tn", ":TestNearest<cr>", opts({ desc = "Test nearest" }))
    vim.api.nvim_set_keymap("n", "<leader>tf", ":TestFile<cr>", opts({ desc = "Test file" }))
    vim.api.nvim_set_keymap("n", "<leader>ts", ":TestSuite<cr>", opts({ desc = "Test suite" }))
  end,
}
