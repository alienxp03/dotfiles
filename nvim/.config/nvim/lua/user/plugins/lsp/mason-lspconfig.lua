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
      automatic_enable = false,
    })

    -- Setup all servers
    local all_servers = mason_lspconfig.get_installed_servers()

    -- Setup remaining servers with default config
    local excluded_servers = { "sorbet", "ruby_lsp", "rubocop" } -- Exclude these from auto-setup

    for _, server_name in ipairs(all_servers) do
      if not vim.tbl_contains(excluded_servers, server_name) then
        lspconfig[server_name].setup({
          capabilities = capabilities,
        })
      end
    end
  end,
}
