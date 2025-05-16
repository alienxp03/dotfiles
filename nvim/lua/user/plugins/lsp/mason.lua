return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    -- import mason
    local mason = require("mason")

    -- import mason-lspconfig
    -- local mason_lspconfig = require("mason-lspconfig")

    -- enable mason and configure icons
    mason.setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    -- mason_lspconfig.setup({
    --   -- list of servers for mason to install
    --   ensure_installed = {
    --     -- "bashls",
    --     -- "ts_ls",
    --     -- "docker_compose_language_service",
    --     -- "jsonls",
    --     -- "yamlls",
    --     -- "lua_ls",
    --     -- "emmet_ls",
    --     -- "html",
    --     -- "dockerls",
    --     -- "gopls",
    --     -- "cssls",
    --     -- "terraformls",
    --     -- "tflint",
    --     -- "ruby_lsp",
    --     -- "pyright",
    --   },
    -- auto-install configured servers (with lspconfig)
    -- automatic_installation = true, -- not the same as ensure_installed
    -- })
  end,
}
