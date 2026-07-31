return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    opts = {
      heading = {
        width = "block",
        left_pad = 1,
        right_pad = 1,
      },
      code = {
        style = "normal",
        sign = false,
        width = "block",
        right_pad = 1,
      },
      pipe_table = { preset = "round" },
    },
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
}
