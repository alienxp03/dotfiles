return {
  "saghen/blink.cmp",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "Kaiser-Yang/blink-cmp-dictionary",
  },

  version = "*",
  opts = {
    keymap = {
      preset = "default",
      ["<C-k>"] = { "select_prev", "fallback_to_mappings" },
      ["<C-j>"] = { "select_next", "fallback_to_mappings" },
      ["<C-n>"] = { "snippet_forward", "fallback_to_mappings" },
      ["<C-p>"] = { "snippet_backward", "fallback_to_mappings" },
      ["<CR>"] = { "select_and_accept", "fallback" },
      ["<Tab>"] = {
        function(cmp)
          local supermaven_suggestion = require("supermaven-nvim.completion_preview")
          if supermaven_suggestion.has_suggestion() then
            vim.schedule(function()
              supermaven_suggestion.on_accept_suggestion()
            end)
          end

          return true
        end,
        "select_next",
      },
    },
    appearance = {
      nerd_font_variant = "mono",
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "dictionary" },
      providers = {
        dictionary = {
          module = "blink-cmp-dictionary",
          name = "Dict",
          min_keyword_length = 3,
          opts = {
            dictionary_directories = { vim.fn.expand("~/.dotfiles/nvim/dictionaries") },
          },
        },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
    signature = { enabled = true },
    completion = {
      menu = {
        auto_show = true,
        border = border_chars,
        draw = {
          components = {},
        },
      },
      documentation = { auto_show = true, auto_show_delay_ms = 500 },
    },
  },
  opts_extend = { "sources.default" },
}
