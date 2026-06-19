return {
  "numToStr/Comment.nvim",
  event = "VeryLazy",
  config = function()
    require("Comment").setup({
      pre_hook = function()
        if vim.bo.filetype == "just" or vim.bo.filetype == "justfile" then
          return "#%s"
        end
      end,
      toggler = {
        line = "<C-m>", -- Line-comment toggle keymap
        block = "gbc", -- Block-comment toggle keymap
      },
      opleader = {
        line = "<C-m>", -- Line-comment keymap in VISUAL mode
        block = "gb", -- Block-comment keymap in VISUAL mode
      },
    })

    local ft = require("Comment.ft")
    ft.set("proto", "//%s") -- proto files
    ft.set("yaml", "#%s") -- yaml files
    ft.set("hcl", "#%s") -- hcl files
    ft.set("helm", "#%s") -- helm files
    ft.set("just", "#%s") -- justfiles
    ft.set("eruby", "<%%# %s %%>") -- eruby files
  end,
}
