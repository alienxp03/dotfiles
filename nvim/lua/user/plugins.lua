-- lazyvim
local lazypath = vim.fn.stdpath('data') .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

--Remap space as leader key
vim.api.nvim_set_keymap('', '<Space>', '<Nop>', { noremap = true, silent = true })
vim.g.mapleader = ' '

require('lazy').setup({
  {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v2.x',
    dependencies = {
      -- LSP Support
      {'neovim/nvim-lspconfig'},             -- Required
      {                                      -- Optional
        'williamboman/mason.nvim',
        build = function()
          pcall(vim.cmd, 'MasonUpdate')
        end,
      },
      {'williamboman/mason-lspconfig.nvim'}, -- Optional

      -- Autocompletion
      {'hrsh7th/nvim-cmp'},     -- Required
      {'hrsh7th/cmp-nvim-lsp'}, -- Required
      {'L3MON4D3/LuaSnip'},     -- Required
    }
  },

  -- Github Copilot
  'github/copilot.vim',

  -- Autocompletions & snippets
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-nvim-lsp',
  'hrsh7th/cmp-buffer',
  'hrsh7th/cmp-path',
  'onsails/lspkind.nvim',
  'L3MON4D3/LuaSnip',
  'saadparwaiz1/cmp_luasnip',
  'rafamadriz/friendly-snippets',

  -- Highlight, edit, and navigate code
  {
    'nvim-treesitter/nvim-treesitter', build = ':TSUpdate',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    }
  },
  -- { 'nvim-treesitter/nvim-treesitter',
  --   build = function()
  --     pcall(require('nvim-treesitter.install').update { with_sync = true })
  --   end,
  --   dependencies = {
  --     'nvim-treesitter/nvim-treesitter-textobjects',
  --   }
  -- },

  {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup()
    end
  },

  'windwp/nvim-ts-autotag',

  -- File explorer
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = {
      'nvim-tree/nvim-web-devicons', -- optional, for file icons
    },
  },
  {
    'akinsho/bufferline.nvim', tag = 'v3.*', dependencies = 'nvim-tree/nvim-web-devicons'
  },
  'akinsho/toggleterm.nvim',
  'moll/vim-bbye', -- Bdelete

  -- Navigation
  'christoomey/vim-tmux-navigator',

  -- Comments
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end
  },

  -- Add indentation guides even on blank lines
  {
    'lukas-reineke/indent-blankline.nvim',
    config = function()
      require('indent_blankline').setup {
        char = '┊',
        show_trailing_blankline_indent = false,
      }
    end
  },

  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('indent_blankline').setup {
        char = '┊',
        show_trailing_blankline_indent = false,
      }
    end
  },
  'tpope/vim-fugitive', -- Git related plugins
  'kdheepak/lazygit.nvim',

  {
    'nvim-telescope/telescope.nvim', tag = '0.1.1',
    dependencies = { {'nvim-lua/plenary.nvim'} }
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim', build = 'make'
  },
  'tpope/vim-rhubarb',
  'tpope/vim-surround', -- Change surrounding words
  'nathom/filetype.nvim', -- Faster filetype
  'nvim-lualine/lualine.nvim', -- Fancier statusline
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  'vim-ruby/vim-ruby',
  'slim-template/vim-slim', -- Rails slim
  'dstein64/vim-startuptime', -- Improve startup time
  'ibhagwan/fzf-lua', -- Fuzzy Finder (files, lsp, etc)
  'nvim-pack/nvim-spectre', -- Search and replace
  'sbdchd/neoformat', -- Indent
  'mg979/vim-visual-multi',
  'wakatime/vim-wakatime', -- Wakatime

  -- Themes
  'folke/tokyonight.nvim',
  'NLKNguyen/papercolor-theme',
  'navarasu/onedark.nvim',
  {
    'catppuccin/nvim', as = 'catppuccin'
  },
})

