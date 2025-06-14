return {
  "williamboman/mason-lspconfig.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    local mason_lspconfig = require("mason-lspconfig")
    local lspconfig = require("lspconfig")
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    mason_lspconfig.setup({
      -- List of servers for mason to install
      ensure_installed = {
        "lua_ls",
        "bashls",
        "docker_compose_language_service",
        "jsonls",
        "yamlls",
        "html",
        "cssls",
        "dockerls",
        "gopls",
        "terraformls",
        "pyright",
        "ts_ls",
        "emmet_ls",
        -- "ruby_lsp", -- Managed manually via mise
      },
      -- Auto-install configured servers with lspconfig
      automatic_installation = true,
    })

    -- Manual server configurations with custom settings
    local server_configs = {
      jsonls = {
        capabilities = capabilities,
      },
      yamlls = {
        capabilities = capabilities,
        settings = {
          yaml = {
            validate = false,
            keyOrdering = false,
          },
        },
      },
      lua_ls = {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              enable = false,
              globals = { "vim" },
            },
            workspace = {
              library = {
                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                [vim.fn.stdpath("config") .. "/lua"] = true,
              },
            },
          },
        },
      },
      gopls = {
        capabilities = capabilities,
        settings = {
          gopls = {
            usePlaceHolders = true,
          },
        },
      },
      html = {
        capabilities = capabilities,
        filetypes = { "html", "slim" },
      },
      emmet_ls = {
        capabilities = capabilities,
        filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less" },
      },
    }

    -- Setup all servers
    local all_servers = mason_lspconfig.get_installed_servers()
    
    -- Setup servers with custom configurations
    for server, config in pairs(server_configs) do
      lspconfig[server].setup(config)
    end

    -- Setup remaining servers with default config
    local excluded_servers = { "sorbet", "ruby_lsp", "rubocop" } -- Exclude these from auto-setup
    
    for _, server_name in ipairs(all_servers) do
      if not server_configs[server_name] and not vim.tbl_contains(excluded_servers, server_name) then
        lspconfig[server_name].setup({
          capabilities = capabilities,
        })
      end
    end
  end,
}

