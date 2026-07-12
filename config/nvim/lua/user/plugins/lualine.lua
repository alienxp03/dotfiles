return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons", "arkav/lualine-lsp-progress" },
  config = function()
    require("lualine").setup({
      options = {
        theme = "gruvbox",
        disabled_filetypes = {
          statusline = {
            "snacks_picker_input",
            "snacks_picker_list",
            "snacks_picker_preview",
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
          {
            "filetype",
          },
        },
        lualine_x = {
          {
            "lsp_status",
            icon = "",
            symbols = {
              -- Standard unicode symbols to cycle through for LSP progress:
              spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
              done = "✓",
              separator = " ",
            },
            ignore_lsp = {},
          },
        },
        lualine_y = {},
      },
    })
  end,
}
