return {
  "nvim-lualine/lualine.nvim",
  config = function()
    require("lualine").setup({
      extensions = {
        "nvim-tree",
      },
      options = {
        theme = "gruvbox",
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
