require('fzf-lua').setup {
  winopts = {
    height = 0.98,
    width = 0.98,
    preview = {
      horizontal = 'right:75%'
    },
  },
  files = {
    fzf_opts = {
      ["-i"] = "" -- case insensitive
    }
  }
}
