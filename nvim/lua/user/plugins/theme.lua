return {
  "folke/tokyonight.nvim",
  dependencies = {
    "rebelot/kanagawa.nvim",
    "EdenEast/nightfox.nvim",
    "AlexvZyl/nordic.nvim",
    "catppuccin/nvim",
    "marko-cerovac/material.nvim",
    "ramojus/mellifluous.nvim",
    "neanias/everforest-nvim",
    "zenbones-theme/zenbones.nvim",
    "rktjmp/lush.nvim",
  },
  config = function()
    -- require("tokyonight").setup({
    --   style = "storm",
    -- })
    -- vim.cmd([[colorscheme nightfox]])

    vim.cmd([[colorscheme kanagawa-wave]])
    -- vim.cmd([[colorscheme kanagawa-dragon]]) -- night mode

    -- transparent background
    vim.cmd("highlight Normal guibg=none ctermbg=none")
  end,
}
