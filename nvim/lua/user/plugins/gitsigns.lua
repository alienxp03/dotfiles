return {
  "lewis6991/gitsigns.nvim",
  config = function()
    local highlight = {
      "CursorColumn",
      "Whitespace",
    }
    require("gitsigns").setup()
  end,
}
