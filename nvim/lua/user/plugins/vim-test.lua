return {
  "vim-test/vim-test",
  dependencies = {
    "preservim/vimux",
  },
  config = function()
    vim.cmd("let test#strategy = 'vimux'")

    vim.g["test#go#gotest#options"] = {
      nearest = "-v",
      file = "-v",
    }
  end,
}
