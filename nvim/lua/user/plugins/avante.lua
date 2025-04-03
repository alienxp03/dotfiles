return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = "*",
  lazy = true,
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "zbirenbaum/copilot.lua",
  },
  opts = {
    provider = "gemini",
    gemini = {
      endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
      -- model = "gemini-1.5-flash-latest",
      model = "gemini-2.0-flash-exp",
      timeout = 30000, -- Timeout in milliseconds
      temperature = 0,
      max_tokens = 4096,
    },
    -- provide = "copilot",
    -- copilot = {
    --   endpoint = "https://api.githubcopilot.com",
    --   model = "gpt-4o-2024-08-06",
    --   proxy = nil, -- [protocol://]host[:port] Use this proxy
    --   allow_insecure = false, -- Allow insecure server connections
    --   timeout = 30000, -- Timeout in milliseconds
    --   temperature = 0,
    --   max_tokens = 4096,
    -- },
    -- mappings = {
    --   ask = "<leader>ch",
    -- },
    -- provider = "copilot",
    -- copilot = {
    --   endpoint = "https://api.githubcopilot.com",
    --   -- model = "gpt-4o-2024-08-06",
    --   -- model = "o1",
    --   model = "claude-3.7-sonnet",
    --   proxy = nil,
    --   allow_insecure = false,
    --   timeout = 30000,
    --   temperature = 0,
    --   max_tokens = 8192,
    -- },
  },
  -- config = function()
  --   require("avante").setup({
  --     provider = "copilot",
  --     copilot = {
  --       endpoint = "https://api.githubcopilot.com",
  --       -- model = "gpt-4o-2024-08-06",
  --       -- model = "o1",
  --       model = "claude-3.7-sonnet",
  --       proxy = nil,
  --       allow_insecure = false,
  --       timeout = 30000,
  --       temperature = 0,
  --       max_tokens = 8192,
  --     },
  --     -- auto_suggestions_provider = "copilot",
  --     behaviour = {
  --       auto_suggestions = false, -- Experimental stage
  --       auto_set_highlight_group = true,
  --       auto_set_keymaps = false,
  --       auto_apply_diff_after_generation = false,
  --       support_paste_from_clipboard = true,
  --     },
  --     mappings = {
  --       ask = "<leader>aa",
  --     },
  --   })
  -- end,
}
