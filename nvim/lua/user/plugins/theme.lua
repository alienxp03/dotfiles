return {
  "folke/tokyonight.nvim",
  config = function()
    require("tokyonight").setup({
      style = "storm"
    })

    vim.cmd [[colorscheme tokyonight]]
    -- transparent background
    -- vim.cmd("highlight Normal guibg=none ctermbg=none")
  end
}
