-- plugins that doesn't require any configuration
return {
    -- Autocompletions & snippets
  'sbdchd/neoformat',
  'tpope/vim-fugitive', -- Git related plugins
  'kdheepak/lazygit.nvim',
  'tpope/vim-rhubarb',
  'tpope/vim-surround', -- Change surrounding words
  'nathom/filetype.nvim', -- Faster filetype
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  'vim-ruby/vim-ruby',
  'slim-template/vim-slim', -- Rails slim
  'dstein64/vim-startuptime', -- Improve startup time
  'nvim-pack/nvim-spectre', -- Search and replace
  'sbdchd/neoformat', -- Indent
  'mg979/vim-visual-multi',
  'wakatime/vim-wakatime', -- Wakatime
  'folke/neodev.nvim', -- Neovim development

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
    'akinsho/bufferline.nvim', dependencies = 'nvim-tree/nvim-web-devicons'
  },
  {
    'echasnovski/mini.move', version = '*',
    config = function()
      require('mini.move').setup()
    end
  },
  'akinsho/toggleterm.nvim',
  'moll/vim-bbye', -- Bdelete

  -- Navigation
  'christoomey/vim-tmux-navigator',
  'ThePrimeagen/harpoon',

  -- Comments
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
    end
  },
}
