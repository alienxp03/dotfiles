local opts = { noremap = true, silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "

-- Clipboard
keymap("n", "<leader>cb", ":lua require('neoclip.fzf')()<cr>", opts)

-- Do not yank with x
keymap("n", "x", '"_x', opts)
keymap("n", "d", '"_d', opts)

-- Clear search
keymap("n", "<esc><esc>", ":noh<cr>", opts)

-- Save shortcut
keymap("n", "<C-s>", ":w<cr>", opts)
keymap("i", "<C-s>", "<esc>:w<cr>", opts)

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)

-- fzf-lua
keymap("n", "<C-p>", ":FzfLua files<CR>", { desc = "Find files" } )
keymap("n", "<leader>fp", ":FzfLua live_grep_glob<CR>", { desc = "Search text current" } )
keymap("n", "<leader>ff", ":FzfLua blines<CR>", { desc = "Live grep current buffer" } )
keymap("n", "<leader>gd", ":FzfLua lsp_definitions<CR>", { desc = "Search text current" } )
keymap("n", "<leader>ds", ":FzfLua lsp_document_symbols<CR>", { desc = "Document symbols" } )

-- nvim-spectre
keymap("n", "<leader>fr", ":lua require('spectre').open_visual({ is_insert_mode = true })<cr>", opts)

-- Ntree explorer
keymap("n", "<leader>e", ":NvimTreeToggle<cr>", opts)

-- Buffers
keymap("n", "<leader>q", ":Bdelete<cr>", { desc = "Close current buffer" })

-- Don't replace yanked word
keymap("x", "<leader>p", [["_dP]], opts)
-- Normal paste
keymap("v", "p", '"_dP', opts)

-- Keep things in the middle 
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "n", "nzzzv", opts)
keymap("n", "N", "Nzzzv", opts)

-- Copy paste
keymap("n", "pp", '"0p', opts)

-- Indent
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)


-- Visual Block --
-- Move text up and down
keymap("v", "J", ":m '>+1<CR>gv=gv", opts)
keymap("v", "K", ":m '<-2<CR>gv=gv", opts)

keymap("n", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
keymap("n", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Search and replace
keymap("n", "<leader>rp", ":lua require('spectre').open()<cr>", { desc = "Find and replace in project" })
keymap("n", "<leader>rf", ":lua require('spectre').open_file_search()<cr>", { desc = "Find and replace in file" })

-- Copy path
keymap("n", "<leader>cp", ":let @+=@%<cr>", { desc = "Copy relative path" })
keymap("n", "<leader>cf", ":let @+=expand('%:p')<cr>", { desc = "Copy full path" })

-- Replace word on current cursor
keymap("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>", { desc = "Replace current word" })

-- Lazygit
keymap("n", "<leader>gl", ":LazyGit<cr>", { desc = "LazyGit" })
