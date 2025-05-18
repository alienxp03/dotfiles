return {
  "saghen/blink.cmp",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "onsails/lspkind.nvim",
  },
  version = "*",
  opts = {
    keymap = {
      preset = "enter",
      ["<C-k>"] = { "select_prev", "fallback_to_mappings" },
      ["<C-j>"] = { "select_next", "fallback_to_mappings" },
      ["<C-n>"] = { "snippet_forward", "fallback_to_mappings" },
      ["<C-p>"] = { "snippet_backward", "fallback_to_mappings" },
      -- ["<CR>"] = { "select_and_accept", "fallback" },
      ["<Tab>"] = {
        function(cmp)
          local ok, supermaven = pcall(require, "supermaven-nvim.completion_preview")
          if ok and supermaven.has_suggestion() then
            vim.schedule(supermaven.on_accept_suggestion)
            return true
          end
        end,
        "select_next",
        "fallback",
      },
      ["<C-x>"] = { "hide" },
    },
    appearance = {
      nerd_font_variant = "mono",
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "cmdline" },
      providers = {
        buffer = {
          opts = {
            -- Performance goes brrr
            -- get all buffers, even ones like neo-tree
            -- get_bufnrs = vim.api.nvim_list_bufs
            -- or (recommended) filter to only "normal" buffers
            get_bufnrs = function()
              return vim.tbl_filter(function(bufnr)
                return vim.bo[bufnr].buftype == ""
              end, vim.api.nvim_list_bufs())
            end,
          },
        },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
    signature = { enabled = true },
    completion = {
      ghost_text = {
        enabled = false,
      },
      list = {
        selection = {
          preselect = false,
          auto_insert = false,
        },
      },
      menu = {
        auto_show = true,
        draw = {
          columns = {
            { "label", "label_description", gap = 1 },
            { "kind_icon" },
            {
              "kind",
            },
          },
          components = {
            kind_icon = {
              text = function(ctx)
                local lspkind = require("lspkind")
                local icon = ctx.kind_icon
                if vim.tbl_contains({ "Path" }, ctx.source_name) then
                  local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label)
                  if dev_icon then
                    icon = dev_icon
                  end
                else
                  icon = require("lspkind").symbolic(ctx.kind, {
                    mode = "symbol",
                  })
                end

                return icon .. ctx.icon_gap
              end,

              highlight = function(ctx)
                local hl = ctx.kind_hl
                if vim.tbl_contains({ "Path" }, ctx.source_name) then
                  local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
                  if dev_icon then
                    hl = dev_hl
                  end
                end
                return hl
              end,
            },
          },
        },
      },
      documentation = { auto_show = true, auto_show_delay_ms = 0 },
    },
    cmdline = {
      completion = { menu = { auto_show = false } },
    },
  },
  opts_extend = { "sources.default" },
}
