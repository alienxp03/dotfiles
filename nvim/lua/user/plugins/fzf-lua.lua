return {
  "ibhagwan/fzf-lua", -- Fuzzy Finder (files, lsp, etc)
  config = function()
    require("fzf-lua").setup({
      bat = {
        cmd = "bat",
        args = "--color=always --style=numbers,changes",
      },
      previewers = {
        builtin = {
          hl_cursorline = "Search", -- cursor line highlight
          extensions = {
            ["png"] = { "chafa", "{file}" },
            ["svg"] = { "chafa", "{file}" },
            ["jpg"] = { "chafa", "{file}" },
          },
        },
      },
      winopts = {
        height = 0.98,
        width = 0.98,
        preview = {
          horizontal = "right:75%",
        },
      },
      grep = {
        rg_opts = "--hidden --column -S -g '!{.git,node_modules}/*'",
      },
    })
  end,
}
