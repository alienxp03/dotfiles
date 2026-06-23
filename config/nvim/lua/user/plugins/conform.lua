-- formatter
-- Set NVIM_AUTOFORMAT=false in your shell env to disable autoformat by default
local autoformat_enabled = vim.env.NVIM_AUTOFORMAT ~= "false"

return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    -- Initialize global autoformat state from env (unless already set)
    if vim.g.disable_autoformat == nil then
      vim.g.disable_autoformat = not autoformat_enabled
    end

    conform.setup({
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        lua = { "stylua" },
        ruby = { "rubocop" },
        eruby = { "htmlbeautifier" },
        hcl = { "terraform_fmt" },
        ["_"] = { "trim_whitespace" },
        go = { "gofmt", "goimports" },
      },

      format_after_save = function(bufnr)
        -- Disable with a global or buffer-local variable
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 500, lsp_format = "fallback" }
      end,
    })

    -- Auto organize imports on save (language-agnostic, works with any LSP that supports it)
    vim.api.nvim_create_autocmd("BufWritePre", {
      callback = function(args)
        local bufnr = args.buf
        local clients = vim.lsp.get_clients({ bufnr = bufnr })
        for _, client in ipairs(clients) do
          if client:supports_method("textDocument/codeAction") then
            local params = {
              textDocument = vim.lsp.util.make_text_document_params(bufnr),
              range = {
                start = { line = 0, character = 0 },
                ["end"] = { line = vim.api.nvim_buf_line_count(bufnr), character = 0 },
              },
              context = { only = { "source.addMissingImports" }, diagnostics = {} },
            }
            local result = client:request_sync("textDocument/codeAction", params, 3000, bufnr)
            if result and result.result then
              for _, action in ipairs(result.result) do
                if action.edit then
                  vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
                end
              end
            end
          end
        end
      end,
    })

    vim.api.nvim_create_user_command("FormatDisable", function(args)
      if args.bang then
        -- FormatDisable! will disable formatting just for this buffer
        vim.b.disable_autoformat = true
      else
        vim.g.disable_autoformat = true
      end
    end, {
      desc = "Disable autoformat-on-save",
      bang = true,
    })
    vim.api.nvim_create_user_command("FormatEnable", function()
      vim.b.disable_autoformat = false
      vim.g.disable_autoformat = false
    end, {
      desc = "Re-enable autoformat-on-save",
    })
  end,
}
