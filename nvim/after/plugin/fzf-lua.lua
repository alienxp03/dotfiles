require('fzf-lua').setup {
  winopts = {
    height = 0.98,
    width = 0.98,
    preview = {
      horizontal = 'right:75%'
    },
  },
  grep = {
    rg_opts = "--hidden --column -S -g '!{.git,node_modules}/*'",
  }
}
