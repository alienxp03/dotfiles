return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    -- "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    "b0o/schemastore.nvim",
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
      -- Ruby LSP server - using mise shims (recommended over Mason)
      ruby_lsp = {
        cmd = { home_path .. "/.local/share/mise/shims/ruby-lsp" },
        root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
        init_options = {
          formatter = "rubocop",
          linters = { "rubocop" },
          addonSettings = {
            ["Ruby LSP Rails"] = {
              enablePendingMigrationsPrompt = false,
            },
            ["Ruby LSP RuboCop"] = {
              enabled = true,
            },
          },
        },
        on_attach = function(client, bufnr)
          -- Add custom Ruby LSP functionality
          vim.keymap.set("n", "<leader>rd", function()
            vim.lsp.buf.execute_command({
              command = "rubyLsp.showSyntaxTree",
              arguments = { vim.uri_from_bufnr(bufnr) },
            })
          end, { buffer = bufnr, desc = "Show Ruby syntax tree" })

          -- Show Ruby dependencies command
          vim.api.nvim_buf_create_user_command(bufnr, "ShowRubyDeps", function()
            local params = {
              command = "rubyLsp.showDependencies",
              arguments = { vim.uri_from_bufnr(bufnr) },
            }
            vim.lsp.buf.execute_command(params)
          end, { desc = "Show Ruby dependencies" })
        end,
      },
      -- SQL LSP server (if needed)
      sqlls = {},
      yamlls = {
        settings = {
          yaml = {
            schemaStore = {
              -- You must disable built-in schemaStore support if you want to use
              -- this plugin and its advanced options like `ignore`.
              enable = false,
              -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
              url = "",
            },
            schemas = require("schemastore").yaml.schemas({
              extra = {
                {
                  name = "Kubernetes",
                  description = "Kubernetes resource manifest",
                  url = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.34.1-standalone/all.json",
                  fileMatch = {
                    "**/*.yaml",
                  },
                },
              },
            }),
          },
        },
      },
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
