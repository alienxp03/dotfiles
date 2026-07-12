vim.opt.wrap = true
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.cursorline = false
vim.opt.showmode = false
vim.opt.clipboard = "unnamedplus"
vim.opt.swapfile = false
vim.opt.foldenable = false

vim.keymap.set("n", "q", "ZQ", { silent = true })
vim.keymap.set("n", "<S-q><S-q>", "ZQ", { silent = true })
