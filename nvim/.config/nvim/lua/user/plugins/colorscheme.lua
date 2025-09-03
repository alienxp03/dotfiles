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
    { "ellisonleao/gruvbox.nvim", lazy = true },
    { "NLKNguyen/papercolor-theme", lazy = true },
    { "ribru17/bamboo.nvim", lazy = true },
  },
  config = function()
    vim.o.background = "dark"

    -- require("gruvbox").setup({})
    require("tokyonight").setup({})
    vim.cmd([[colorscheme tokyonight-night]])

    -- vim.cmd([[colorscheme gruvbox]])

    -- vim.cmd([[colorscheme PaperColor]])

    -- require("bamboo").setup()
    -- vim.cmd([[colorscheme bamboo-multiplex]])

    -- vim.cmd([[colorscheme terrafox]])
    -- vim.cmd([[colorscheme everforest]])
    -- vim.cmd([[colorscheme nightfox]])
    -- vim.cmd([[colorscheme kanagawa-wave]])
    -- vim.cmd([[colorscheme kanagawa-dragon]]) -- night mode

    -- transparent background
    -- vim.cmd("highlight Normal guibg=none ctermbg=none")
  end,
}
