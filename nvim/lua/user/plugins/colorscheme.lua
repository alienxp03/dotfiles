return {
  "rebelot/kanagawa.nvim", -- Primary theme
  lazy = false,
  priority = 1000,
  dependencies = {
    -- Other themes lazy loaded
    { "folke/tokyonight.nvim", lazy = true },
    { "EdenEast/nightfox.nvim", lazy = true },
    { "AlexvZyl/nordic.nvim", lazy = true },
    { "catppuccin/nvim", lazy = true },
    { "marko-cerovac/material.nvim", lazy = true },
    { "ramojus/mellifluous.nvim", lazy = true },
    { "neanias/everforest-nvim", lazy = true },
    { "zenbones-theme/zenbones.nvim", lazy = true },
    { "rktjmp/lush.nvim", lazy = true },
  },
  config = function()
    -- require("tokyonight").setup({
    --   style = "storm",
    -- })
    vim.cmd([[colorscheme terafox]])
    -- vim.cmd([[colorscheme nightfox]])

    -- vim.cmd([[colorscheme kanagawa-wave]])
    -- vim.cmd([[colorscheme kanagawa-dragon]]) -- night mode

    -- transparent background
    vim.cmd("highlight Normal guibg=none ctermbg=none")
  end,
}
