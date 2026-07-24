return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  config = function()
    local actions = require("diffview.actions")

    require("diffview").setup({
      keymaps = {
        file_panel = {
          { "n", "j", actions.select_next_entry },
          { "n", "k", actions.select_prev_entry },
        },
      },
    })
  end,
}
