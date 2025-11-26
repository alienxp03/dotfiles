return {
  "monkoose/neocodeium",
  event = "VeryLazy",
  config = function()
    local neocodeium = require("neocodeium")
    neocodeium.setup()

    vim.keymap.set("i", "<Tab>", function()
      require("neocodeium").accept()
    end)
    vim.keymap.set("i", "<C-r>", function()
      require("neocodeium").cycle_or_complete()
    end)
    vim.keymap.set("i", "<C-e>", function()
      require("neocodeium").cycle_or_complete(-1)
    end)
  end,
}
