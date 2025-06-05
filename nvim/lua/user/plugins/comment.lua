return {
  "numToStr/Comment.nvim",
  config = function()
    require("Comment").setup({
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
    ft.set("eruby", "<%%# %s %%>") -- eruby files
  end,
}
