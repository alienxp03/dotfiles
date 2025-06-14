return {
  "mfussenegger/nvim-lint",
  event = {
    "BufReadPre",
    "BufNewFile",
  },
  config = function()
    local lint = require("lint")

    -- Configure jsonlint to use Mason's path
    lint.linters.jsonlint.cmd = vim.fn.stdpath("data") .. "/mason/bin/jsonlint"

    lint.linters_by_ft = {
      lua = { "luacheck" },
      -- yaml = { "yamllint" },
      json = { "jsonlint" },
      -- typescript = { "eslint_d" },
    }

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
