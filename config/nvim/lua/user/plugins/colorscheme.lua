return {
  -- Tokyo Night fallback. Uncomment this block and comment out Luna below to switch back.
  -- {
  --   "folke/tokyonight.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     vim.o.background = "dark"
  --
  --     require("tokyonight").setup({
  --       transparent = true,
  --       styles = {
  --         sidebars = "transparent",
  --         floats = "transparent",
  --       },
  --     })
  --     vim.cmd.colorscheme("tokyonight-night")
  --   end,
  -- },
  "wtfox/luna.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    vim.o.background = "dark"

    require("luna").setup({
      transparent = true,
      accent = 1.0,
    })
    vim.cmd.colorscheme("luna")
    vim.api.nvim_set_hl(0, "Visual", {
      bg = "#3b5b7a",
      fg = "#ffffff",
      bold = true,
    })
    vim.api.nvim_set_hl(0, "SnacksPickerFile", {
      fg = "#ffffff",
      bold = true,
    })
    vim.api.nvim_set_hl(0, "SnacksPickerDir", {
      fg = "#7f849c",
    })
    vim.api.nvim_set_hl(0, "SnacksPickerDirectory", {
      fg = "#7f849c",
      italic = true,
    })
  end,
}
