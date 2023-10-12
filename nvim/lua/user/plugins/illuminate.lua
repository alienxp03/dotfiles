return {
  "RRethy/vim-illuminate",
  config = function()
    local illuminate = require("illuminate")

    illuminate.configure({
      providers = {
        "lsp",
        "treesitter",
        "regex",
      },
    })

    vim.cmd("IlluminatePause")
  end,
}
