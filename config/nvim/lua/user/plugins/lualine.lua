return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "arkav/lualine-lsp-progress" },
  event = "VeryLazy",
  config = function()
    require("lualine").setup({
      options = {
        theme = "luna",
        disabled_filetypes = {
          statusline = {
            "snacks_picker_input",
            "snacks_picker_list",
            "snacks_picker_preview",
            "snacks_dashboard",
          },
        },
      },
      sections = {
        lualine_b = { "diff", "diagnostics" },
        lualine_c = {
          {
            "filename",
            path = 1,
          },
        },
        lualine_x = {
          "searchcount",
          "selectioncount",
        },
        lualine_y = {},
        lualine_z = { "filetype", "location" },
      },
    })
  end,
}
