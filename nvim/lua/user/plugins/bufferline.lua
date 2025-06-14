return {
  "akinsho/bufferline.nvim",
  version = "*",
  event = "VeryLazy",
  config = function()
    require("bufferline").setup({})
  end,
}
