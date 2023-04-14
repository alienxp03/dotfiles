local lsp = require('lsp-zero').preset({})
local lspconfig = require("lspconfig")
local home_path = os.getenv("HOME")

lsp.on_attach(function(_, bufnr)
  lsp.default_keymaps({buffer = bufnr})
end)

local servers = {
  html = {
    filetypes = { "html", "slim" }
  },
  solargraph = {
    cmd = { home_path .. "/.rbenv/shims/solargraph", 'stdio' },
    root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
    settings = {
      solargraph = {
        autoformat = true,
        completion = true,
        diagnostic = true,
        folding = true,
        references = true,
        rename = true,
        symbols = true
      }
    }
  }
}

lsp.ensure_installed({
  "bashls",
  "tsserver",
  "solargraph",
  "docker_compose_language_service",
  "jsonls",
  "yamlls",
  "lua_ls",
  "html",
  "dockerls",
  "gopls",
  "cssls"
})

for name, config in pairs(servers) do
  if type(config) ~= "table" then
    config = {}
  end

  config = vim.tbl_deep_extend("force", {
    on_attach = on_attach,
    capabilities = capabilities
  }, config)

  lsp.configure(name, config)
end

-- (Optional) Configure lua language server for neovim
require('lspconfig').lua_ls.setup(lsp.nvim_lua_ls())

lsp.setup()
