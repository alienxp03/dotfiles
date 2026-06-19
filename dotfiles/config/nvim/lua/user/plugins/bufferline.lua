return {
  "akinsho/bufferline.nvim",
  version = "*",
  event = "VeryLazy",
  config = function()
    require("bufferline").setup({
      options = {
        sort_by = "insert_at_end",
      },
    })
  end,
}
