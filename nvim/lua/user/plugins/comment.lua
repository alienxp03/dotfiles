return {
  "numToStr/Comment.nvim",
  config = function()
    require("Comment").setup()

    local ft = require("Comment.ft")
    ft.set("proto", "//%s") -- proto files
    ft.set("hcl", "#%s") -- terraform files
  end,
}
