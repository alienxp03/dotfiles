return {
  "nvim-lualine/lualine.nvim", -- Fancier statusline
  config = function()
    require("lualine").setup({
      options = {
        theme = "papercolor_light",
      },
      sections = {
        lualine_b = {}, -- Disable branch
        lualine_c = {
          {
            "filename",
            path = 1,
          },
        },
        lualine_x = {}, -- Disable branch
      },
    })
  end,
}
