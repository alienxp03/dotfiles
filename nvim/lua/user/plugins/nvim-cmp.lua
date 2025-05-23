return {
  -- "hrsh7th/nvim-cmp",
  -- event = "InsertEnter",
  -- dependencies = {
  --   "hrsh7th/cmp-buffer", -- source for text in buffer
  --   "hrsh7th/cmp-path", -- source for file system paths
  --   "hrsh7th/cmp-nvim-lsp",
  --   "L3MON4D3/LuaSnip", -- snippet engine
  --   "saadparwaiz1/cmp_luasnip", -- for autocompletion
  --   "rafamadriz/friendly-snippets", -- useful snippets
  --   "onsails/lspkind.nvim", -- vs-code like pictograms
  --   "nvim-tree/nvim-web-devicons", -- optional, for file icons
  -- },
  -- config = function()
  --   local luasnip = require("luasnip")
  --   local cmp = require("cmp")
  --   local lspkind = require("lspkind")
  --   -- local neocodeium = require("neocodeium")
  --   -- local commands = require("neocodeium.commands")
  --
  --   -- loads vscode style snippets from installed plugins (e.g. friendly-snippets)
  --   require("luasnip.loaders.from_vscode").lazy_load()
  --   require("luasnip.loaders.from_vscode").load({ paths = { "~/.dotfiles/nvim/snippets" } })
  --
  --   cmp.setup({
  --     preselect = cmp.PreselectMode.None,
  --     sources = {
  --       { name = "nvim_lsp" },
  --       { name = "luasnip" },
  --       { name = "buffer" },
  --       { name = "path" },
  --     },
  --     snippet = {
  --       expand = function(args)
  --         luasnip.lsp_expand(args.body)
  --       end,
  --     },
  --     mapping = cmp.mapping.preset.insert({
  --       ["<C-d>"] = cmp.mapping.scroll_docs(-4),
  --       ["<C-f>"] = cmp.mapping.scroll_docs(4),
  --       ["<C-Space>"] = cmp.mapping.complete(),
  --       ["<CR>"] = cmp.mapping.confirm({
  --         behavior = cmp.ConfirmBehavior.Replace,
  --         select = false,
  --       }),
  --       ["<C-j>"] = cmp.mapping.select_next_item(),
  --       ["<C-k>"] = cmp.mapping.select_prev_item(),
  --       ["<Tab>"] = cmp.mapping(function(fallback)
  --         local supermaven_suggestion = require("supermaven-nvim.completion_preview")
  --
  --         if luasnip.expandable() then
  --           luasnip.expand()
  --         -- elseif neocodeium.visible() then
  --         --   neocodeium.accept()
  --         elseif supermaven_suggestion.has_suggestion() then
  --           supermaven_suggestion.on_accept_suggestion()
  --         elseif cmp.visible() then
  --           cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
  --           luasnip.expand()
  --         else
  --           fallback()
  --         end
  --       end, {
  --         "i",
  --         "s",
  --       }),
  --     }),
  --     -- configure lspkind for vs-code like pictograms in completion menu
  --     formatting = {
  --       format = lspkind.cmp_format({
  --         maxwidth = 50,
  --         ellipsis_char = "...",
  --       }),
  --     },
  --   })
  -- end,
}
