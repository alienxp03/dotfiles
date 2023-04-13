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
  ruby_ls = {
    cmd = { home_path .. "/.rbenv/shims/ruby-lsp" },
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

--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    if vim.lsp.buf.format then
      vim.lsp.buf.format()
    elseif vim.lsp.buf.formatting then
      vim.lsp.buf.formatting()
    end
  end, { desc = 'Format current buffer with LSP' })
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

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
