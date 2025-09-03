-- faster(?) search
return {
  "folke/flash.nvim",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {},
  -- stylua: ignore
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
  },
  config = function()
    require("flash").setup({
      search = {
        mode = function(str)
          return "\\<" .. str
        end,
      },
    })
  end,
}
