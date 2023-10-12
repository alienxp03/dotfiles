return {
  "ibhagwan/fzf-lua", -- Fuzzy Finder (files, lsp, etc)
  config = function()
    require("fzf-lua").setup({
      previewers = {
        builtin = {
          hl_cursorline = "Search", -- cursor line highlight
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
