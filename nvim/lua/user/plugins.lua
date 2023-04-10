-- Install packer
local install_path = vim.fn.stdpath 'data' .. '/site/pack/packer/start/packer.nvim'
if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
  vim.cmd [[packadd packer.nvim]]
end

require('packer').startup(function(use)
  -- Package manager
  use("wbthomason/packer.nvim")
  use {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v2.x',
    requires = {
      -- LSP Support
      {'neovim/nvim-lspconfig'},             -- Required
      {                                      -- Optional
        'williamboman/mason.nvim',
        run = function()
          pcall(vim.cmd, 'MasonUpdate')
        end,
      },
      {'williamboman/mason-lspconfig.nvim'}, -- Optional

      -- Autocompletion
      {'hrsh7th/nvim-cmp'},     -- Required
      {'hrsh7th/cmp-nvim-lsp'}, -- Required
      {'L3MON4D3/LuaSnip'},     -- Required
    }
  }

  -- Github Copilot
  use { 'github/copilot.vim' }

  -- Autocompletions & snippets
  use { 'hrsh7th/nvim-cmp' }
  use { "hrsh7th/cmp-nvim-lsp" }
  use { "hrsh7th/cmp-buffer" }
  use { "hrsh7th/cmp-path" }
  use { "onsails/lspkind.nvim" }
  use { "L3MON4D3/LuaSnip" }
  use { "saadparwaiz1/cmp_luasnip" }
  use { 'rafamadriz/friendly-snippets' }

  use { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    run = function()
      pcall(require('nvim-treesitter.install').update { with_sync = true })
    end,
  }

  use { -- Additional text objects via treesitter
    'nvim-treesitter/nvim-treesitter-textobjects',
    after = 'nvim-treesitter',
  }

  use {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup()
    end
  }

  use { 'windwp/nvim-ts-autotag' }

  -- File explorer
  use {
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
  }
  use { "akinsho/toggleterm.nvim" }
  use {'akinsho/bufferline.nvim', tag = "v3.*", requires = 'nvim-tree/nvim-web-devicons'}
  use { 'moll/vim-bbye' } -- Bdelete

  -- Navigation
    use { "christoomey/vim-tmux-navigator" }

  -- Comments
  use {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end
  }

  -- Add indentation guides even on blank lines
  use {
    'lukas-reineke/indent-blankline.nvim',
    config = function()
      require('indent_blankline').setup {
        char = '┊',
        show_trailing_blankline_indent = false,
      }
    end
  }

  use {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('indent_blankline').setup {
        char = '┊',
        show_trailing_blankline_indent = false,
      }
    end
  }
  use 'tpope/vim-fugitive' -- Git related plugins
  use 'kdheepak/lazygit.nvim'

  use {
    'nvim-telescope/telescope.nvim', tag = '0.1.1',
    requires = { {'nvim-lua/plenary.nvim'} }
  }
  use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  use 'tpope/vim-rhubarb'
  use "tpope/vim-surround" -- Change surrounding words
  use "nathom/filetype.nvim" -- Faster filetype
  use 'nvim-lualine/lualine.nvim' -- Fancier statusline
  use 'tpope/vim-sleuth' -- Detect tabstop and shiftwidth automatically
  use 'vim-ruby/vim-ruby'
  use 'slim-template/vim-slim' -- Rails slim
  use 'dstein64/vim-startuptime' -- Improve startup time
  use { "ibhagwan/fzf-lua" } -- Fuzzy Finder (files, lsp, etc)
  use { 'nvim-pack/nvim-spectre' } -- Search and replace
  use { 'sbdchd/neoformat' } -- Indent
  use { 'mg979/vim-visual-multi' }
  use { 'wakatime/vim-wakatime' } -- Wakatime

  -- Themes
  use 'folke/tokyonight.nvim'
  use "NLKNguyen/papercolor-theme"
  use 'navarasu/onedark.nvim'
  use { "catppuccin/nvim", as = "catppuccin" }

  -- Add custom plugins to packer from ~/.config/nvim/lua/custom/plugins.lua
  local has_plugins, plugins = pcall(require, 'custom.plugins')
  if has_plugins then
    plugins(use)
  end
end)

-- Automatically source and re-compile packer whenever you save this file 
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

