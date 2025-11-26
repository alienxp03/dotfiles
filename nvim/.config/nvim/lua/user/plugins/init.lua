-- plugins that doesn't require any configuration
return {
  { "sbdchd/neoformat", cmd = "Neoformat" },
  { "tpope/vim-fugitive", cmd = { "Git", "G" } }, -- Git related plugins
  { "kdheepak/lazygit.nvim", cmd = "LazyGit" },
  { "tpope/vim-rhubarb", event = "VeryLazy" },
  { "tpope/vim-surround", event = "VeryLazy" }, -- Change surrounding words
  { "tpope/vim-sleuth", event = "VeryLazy" }, -- Detect tabstop and shiftwidth automatically
  { "vim-ruby/vim-ruby", ft = "ruby" },
  { "slim-template/vim-slim", ft = "slim" }, -- Rails slim
  { "dstein64/vim-startuptime", cmd = "StartupTime" }, -- Improve startup time
  { "wakatime/vim-wakatime", event = "VeryLazy" }, -- Wakatime
  { "folke/neodev.nvim", ft = "lua" }, -- Neovim development
  { "akinsho/toggleterm.nvim", cmd = { "ToggleTerm", "TermExec" } },
  { "christoomey/vim-tmux-navigator", lazy = false }, -- Keep immediate for tmux integration
  { "tpope/vim-endwise", event = "InsertEnter" },
  { "github/copilot.vim", lazy = false },
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
}
