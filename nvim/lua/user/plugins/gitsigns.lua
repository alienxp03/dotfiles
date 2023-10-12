return {
  "lewis6991/gitsigns.nvim",
  dependencies = {},
  config = function()
    local highlight = {
      "CursorColumn",
      "Whitespace",
    }
    require("ibl").setup({
      indent = { highlight = highlight, char = "┊" },
      whitespace = {
        highlight = highlight,
        remove_blankline_trail = false,
      },
      scope = { enabled = false },
    })
    require("gitsigns").setup()
  end,
}
