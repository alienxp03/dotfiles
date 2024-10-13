return {
  "numToStr/Comment.nvim",
  config = function()
    require("Comment").setup()

    local ft = require("Comment.ft")
    ft.set("proto", "//%s") -- proto files
    ft.set("yaml", "#%s") -- yaml files
    ft.set("hcl", "#%s") -- hcl files
    ft.set("helm", "#%s") -- helm files
    ft.set("eruby", "<%%# %s %%>") -- eruby files
  end,
}
