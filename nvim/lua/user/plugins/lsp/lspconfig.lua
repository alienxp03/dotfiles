return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    -- "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
  },
  config = function()
    -- import lspconfig plugin
    local lspconfig = require("lspconfig")

    -- import cmp-nvim-lsp plugin
    -- local cmp_nvim_lsp = require("cmp_nvim_lsp")

    -- used to enable autocompletion (assign to every lsp server config)
    -- local capabilities = cmp_nvim_lsp.default_capabilities()
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    -- Change the Diagnostic symbols in the sign column (gutter)
    -- (not in youtube nvim video)
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    -- Only setup servers not handled by mason-lspconfig
    local home_path = os.getenv("HOME")
    local manual_servers = {
      -- Ruby LSP server - choose one: ruby_lsp or solargraph
      ruby_lsp = {
        cmd = { home_path .. "/.local/share/mise/shims/ruby-lsp" },
        root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
        -- Add environment variables to disable problematic features
        cmd_env = {
          RUBY_LSP_EXPERIMENTAL_FEATURES = "false",
          RUBY_LSP_BUNDLE = "false", -- Disable automatic bundle operations
        },
        init_options = {
          enabledFeatures = {
            "documentHighlights",
            "documentSymbols", 
            "foldingRanges",
            "selectionRanges",
            "semanticHighlighting",
            "formatting",
            "codeActions",
          },
        },
        settings = {
          rubyLsp = {
            -- Disable automatic bundle operations
            bundleGemfile = false,
          },
        },
      },
      -- SQL LSP server (if needed)
      sqlls = {},
    }

    -- Setup manual servers
    for name, config in pairs(manual_servers) do
      if type(config) ~= "table" then
        config = {}
      end

      config = vim.tbl_deep_extend("force", {
        capabilities = capabilities,
      }, config)

      lspconfig[name].setup(config)
    end
  end,
}
