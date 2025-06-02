function opts(options)
  local opts = { noremap = true, silent = true }
  return vim.tbl_deep_extend("force", opts, options or {})
end

--Remap space as leader key
vim.api.nvim_set_keymap("", "<Space>", "<Nop>", { noremap = true, silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

-- Clipboard

-- Clear search
keymap("v", "<Esc><Esc>", "<Esc>", opts({ desc = "clear search" }))
keymap("n", "<Esc><Esc>", ":noh<CR>", opts({ desc = "clear search" }))

-- Save shortcut
keymap("n", "<C-s>", ":w<cr>", opts())
keymap("i", "<C-s>", "<esc>:w<cr>", opts())

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts())
keymap("n", "<C-j>", "<C-w>j", opts())
keymap("n", "<C-k>", "<C-w>k", opts())
keymap("n", "<C-l>", "<C-w>l", opts())

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts())
keymap("n", "<C-Down>", ":resize +2<CR>", opts())
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts())
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts())

-- Navigate buffers
keymap("n", "<S-l>", ":BufferLineCycleNext<CR>", opts())
keymap("n", "<S-h>", ":BufferLineCyclePrev<CR>", opts())

keymap("n", "<leader>lc", ":lua vim.diagnostic.open_float()<cr>", opts({ desc = "Show diagnostic for line" }))
keymap("n", "<leader>lr", ":lua vim.lsp.buf.rename()<cr>", opts({ desc = "LSP rename" }))
keymap("n", "<leader>lh", ":lua vim.lsp.buf.hover()<cr>", opts({ desc = "Show documentation" }))
keymap("n", "<leader>la", ":lua vim.lsp.buf.code_action()<cr>", opts({ desc = " Code action" }))

-- fzf-lua
-- keymap("n", "<C-f>", ":FzfLua live_grep_glob winopts.preview.vertical=down:30%<CR>", opts({ desc = "Find files" }))
-- keymap("n", "<C-p>", ":FzfLua files<CR>", opts({ desc = "Find files" }))
-- keymap("n", "<C-t>", ":FzfLua lgrep_curbuf<CR>", opts({ desc = "Live grep current buffer" }))
-- keymap("n", "<C-b>", ":FzfLua buffers<CR>", opts({ desc = "Open buffers" }))
-- keymap("n", "<leader>fp", ":FzfLua live_grep_glob<CR>", opts({ desc = "Search text current" }))
-- keymap("n", "<leader>ls", ":FzfLua lsp_document_symbols<CR>", opts({ desc = "Document symbols" }))
-- keymap("n", "<leader>ld", ":FzfLua lsp_definitions<CR>", opts({ desc = "Definitions" }))
-- keymap("n", "<leader>lf", ":FzfLua lsp_references<CR>", opts({ desc = "References" }))
-- keymap("n", "<leader>lm", ":FzfLua lsp_implementations<CR>", opts({ desc = "Implementations" }))
-- keymap("n", "<leader>gb", ":FzfLua git_branches<CR>", opts({ desc = "Git branches" }))
-- keymap("n", "<leader>gc", ":FzfLua git_bcommits<CR>", opts({ desc = "Git buffer commits" }))
-- keymap("n", "<leader>gs", ":FzfLua git_status<CR>", opts({ desc = "Git status" }))
-- keymap("n", "<leader>sc", ":FzfLua command_history<CR>", opts({ desc = "Command history" }))
-- keymap("n", "<leader>fk", ":FzfLua keymaps<CR>", opts({ desc = "Keymaps" }))
-- keymap("n", "<leader>ge", ":Git blame<CR>", opts({ desc = "Git blame" }))
-- keymap("v", "<leader>ge", ":Git blame<CR>", opts({ desc = "Git blame" }))

-- Ntree explorer
keymap("n", "<leader>e", ":NvimTreeToggle<cr>", opts())

-- Don't replace yanked word
keymap("x", "<leader>p", [["_dP]], opts())
-- Normal paste
keymap("v", "p", '"_dP', opts())

-- Testing comment gc/gcc shortcut
keymap("x", "<C-g>", "gc", { noremap = false })
keymap("x", "<C-_>-", "gc", { noremap = false })
keymap("x", "<C-->-", "gc", { noremap = false })

-- Keep things in the middle
keymap("n", "<C-d>", "<C-d>zz", opts())
keymap("n", "<C-u>", "<C-u>zz", opts())
keymap("n", "n", "nzzzv", opts())
keymap("n", "N", "Nzzzv", opts())

-- Copy paste
-- keymap("n", "pp", '"0p', opts())

-- split
keymap("n", "<leader>vs", ":vsplit<cr>", opts())
keymap("n", "<leader>hs", ":split<cr>", opts())

-- Indent
keymap("v", "<", "<gv", opts())
keymap("v", ">", ">gv", opts())

-- Move block of code
keymap("n", "<S-j>", ":m .+1<CR>==", opts())
keymap("n", "<S-k>", ":m .-2<CR>==", opts())
keymap("v", "<S-j>", ":m '>+1<CR>gv=gv", opts())
keymap("v", "<S-k>", ":m '<-2<CR>gv=gv", opts())

-- Search and replace
keymap("n", "<leader>rp", ":lua require('spectre').open()<cr>", opts({ desc = "Find and replace in project" }))
keymap("n", "<leader>rf", ":lua require('spectre').open_file_search()<cr>", opts({ desc = "Find and replace in file" }))

-- Copy path
keymap("n", "<leader>cp", ":let @+=@%<cr>", opts({ desc = "Copy relative path" }))
keymap("n", "<leader>cf", ":let @+=expand('%:p')<cr>", opts({ desc = "Copy full path" }))

-- Replace word on current cursor
keymap(
  "n",
  "<leader>s",
  ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>",
  opts({ desc = "Replace current word" })
)

-- Tmux navigation
-- Temporary fix. Seems to be a bug, had to manually declare these bindings for now
keymap("n", "<C-h>", ":TmuxNavigateLeft<cr>", opts())
keymap("n", "<C-j>", ":TmuxNavigateDown<cr>", opts())
keymap("n", "<C-k>", ":TmuxNavigateUp<cr>", opts())
keymap("n", "<C-l>", ":TmuxNavigateRight<cr>", opts())

-- trouble
keymap(
  "n",
  "<leader>xx",
  ":Trouble diagnostics toggle<cr>",
  opts({ desc = "Toggle trouble view", noremap = true, silent = true })
)

-- keymap("n", "<C-o>", ":Legendary<cr>", opts({ desc = "Open legendary menu", noremap = true, silent = true }))

keymap("n", "<leader>tc", ":GoCoverage -p<cr>", opts({ desc = "Run go coverage" }))
vim.keymap.set("n", "<leader>gv", function()
  vim.cmd("GoModTidy")
  vim.cmd("GoModVendor")
end)

keymap("n", "<leader>tn", ":TestNearest<cr>", opts({ desc = "Test nearest" }))
keymap("n", "<leader>tf", ":TestFile<cr>", opts({ desc = "Test file" }))
keymap("n", "<leader>ts", ":TestSuite<cr>", opts({ desc = "Test suite" }))

keymap("n", "<leader>yz", ":Yazi<cr>", opts({ desc = "Open Yazi" }))

-- neo-clip
keymap("n", "<leader>fy", ":lua require('neoclip.fzf')()<cr>", opts({ desc = "View yank history" }))

keymap("n", "<leader>cc", ":CodeCompanionChat Toggle<cr>", opts({ desc = "Toggle code companion" }))
