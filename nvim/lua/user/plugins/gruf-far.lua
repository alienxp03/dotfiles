return {
  "MagicDuck/grug-far.nvim",
  event = "VeryLazy",
  config = function()
    require("grug-far").setup({})

    vim.keymap.set("n", "<leader>rf", ":GrugFar<cr>", { noremap = true, silent = true })
    vim.keymap.set(
      "n",
      "<leader>rp",
      ":lua require('grug-far').open({ prefills = { paths = vim.fn.expand(' % ') } })<cr>",
      { noremap = true, silent = true }
    )
  end,
}
