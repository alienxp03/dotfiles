return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local highlight = {
      "CursorColumn",
      "Whitespace",
    }
    require("gitsigns").setup()
  end,
}
