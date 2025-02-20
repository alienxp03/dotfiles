return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
  },
  config = function()
    -- import lspconfig plugin
    local lspconfig = require("lspconfig")

    -- import cmp-nvim-lsp plugin
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    -- used to enable autocompletion (assign to every lsp server config)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- Change the Diagnostic symbols in the sign column (gutter)
    -- (not in youtube nvim video)
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    local home_path = os.getenv("HOME")
    local servers = {
      html = {
        filetypes = { "html", "slim" },
      },
      emmet_ls = {
        filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less" },
      },
      ts_ls = {},
      cssls = {},
      bashls = {},
      docker_compose_language_service = {},
      jsonls = {},
      yamlls = {
        settings = {
          yaml = {
            validate = false,
            keyOrdering = false,
          },
        },
      },
      dockerls = {},
      gopls = {},
      terraformls = {},
      tflint = {},
      lua_ls = {
        settings = { -- custom settings for lua
          Lua = {
            -- make the language server recognize "vim" global
            diagnostics = {
              enable = false,
              globals = { "vim" },
            },
            workspace = {
              -- make language server aware of runtime files
              library = {
                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                [vim.fn.stdpath("config") .. "/lua"] = true,
              },
            },
          },
        },
      },
      ruby_lsp = {
        cmd = { home_path .. "/.rbenv/shims/ruby-lsp" },
      },
      solargraph = {
        cmd = { home_path .. "/.rbenv/shims/solargraph", "stdio" },
        root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
        init_options = { formatting = true },
        settings = {
          solargraph = {
            autoformat = true,
            completion = true,
            diagnostic = true,
            folding = true,
            references = true,
            rename = true,
            symbols = true,
          },
        },
      },
      pyright = {},
      sqlls = {},
    }

    for name, config in pairs(servers) do
      if type(config) ~= "table" then
        config = {}
      end

      config = vim.tbl_deep_extend("force", {
        capabilities = capabilities,
      }, config)

      -- lsp.configure(name, config)
      lspconfig[name].setup(config)
    end
  end,
}
