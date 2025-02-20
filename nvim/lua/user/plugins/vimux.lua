return {
  "preservim/vimux",
  config = function()
    local keymap = vim.api.nvim_set_keymap

    keymap("n", "<leader>ml", ':VimuxRunCommand("make lint")<cr>', opts({ desc = "make lint" }))
    keymap("n", "<leader>mt", ':VimuxRunCommand("make test | gocol")<cr>', opts({ desc = "make test" }))
    keymap("n", "<leader>mc", ':VimuxRunCommand("make test-cover | gocol")<cr>', opts({ desc = "make test-cover" }))
  end,
}
