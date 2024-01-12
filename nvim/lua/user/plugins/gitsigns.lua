return {
  "lewis6991/gitsigns.nvim",
  dependencies = {
    "lukas-reineke/indent-blankline.nvim",
  },
  config = function()
    local highlight = {
      "CursorColumn",
      "Whitespace",
    }
    require("gitsigns").setup()
  end,
}
