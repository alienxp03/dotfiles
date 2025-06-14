return {
  "ibhagwan/fzf-lua", -- Fuzzy Finder (files, lsp, etc)
  cmd = { "FzfLua" },
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find buffers" },
    { "<leader>fh", "<cmd>FzfLua help_tags<cr>", desc = "Help tags" },
  },
  config = function()
    require("fzf-lua").setup({
      bat = {
        cmd = "bat",
        args = "--color=always --style=numbers,changes",
      },
      previewers = {
        builtin = {
          ["hls.cursorline"] = "Search", -- cursor line highlight
          extensions = {
            ["png"] = { "chafa", "{file}" },
            ["svg"] = { "chafa", "{file}" },
            ["jpg"] = { "chafa", "{file}" },
          },
          syntax_limit_b = 1024 * 100, -- 100KB
        },
      },
      winopts = {
        height = 0.98,
        width = 0.98,
        preview = {
          -- horizontal = "right:75%",
          vertical = "down:75%",
          layout = "vertical",
          wrap = true,
        },
      },
      files = {
        formatter = { "path.filename_first", 2 },
      },
      grep = {
        rg_opts = "--hidden --line-number --color=always --column -S -g '!{.git,node_modules}/*'",
      },
      lsp = {
        jump1 = false,
      },
    })
  end,
}
