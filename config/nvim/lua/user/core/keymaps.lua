function opts(options)
  local opts = { noremap = true, silent = true }
  return vim.tbl_deep_extend("force", opts, options or {})
end

--Remap space as leader key
vim.keymap.set("", "<Space>", "<Nop>", { noremap = true, silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Shorten function name
local keymap = vim.keymap.set

-- Clipboard

-- Clear search
keymap("v", "<Esc><Esc>", "<Esc>", opts({ desc = "clear search" }))
keymap("n", "<Esc><Esc>", ":noh<CR>", opts({ desc = "clear search" }))

-- Save shortcut
keymap("n", "<C-s>", ":w<cr>", opts())
keymap("i", "<C-s>", "<esc>:w<cr>", opts())

-- Better window navigation is configured below with Kitty/tmux edge handling.

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts())
keymap("n", "<C-Down>", ":resize +2<CR>", opts())
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts())
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts())

-- Navigate buffers
keymap("n", "<S-l>", ":BufferLineCycleNext<CR>", opts())
keymap("n", "<S-h>", ":BufferLineCyclePrev<CR>", opts())
keymap("n", "<leader>1", ":BufferLineGoToBuffer 1<CR>", opts())
keymap("n", "<leader>2", ":BufferLineGoToBuffer 2<CR>", opts())
keymap("n", "<leader>3", ":BufferLineGoToBuffer 3<CR>", opts())

keymap("n", "<leader>lc", ":lua vim.diagnostic.open_float()<cr>", opts({ desc = "Show diagnostic for line" }))
keymap("n", "<leader>lr", ":lua vim.lsp.buf.rename()<cr>", opts({ desc = "LSP rename" }))
keymap("n", "<leader>lh", ":lua vim.lsp.buf.hover()<cr>", opts({ desc = "Show documentation" }))
keymap("n", "<leader>la", ":lua vim.lsp.buf.code_action()<cr>", opts({ desc = "Code action" }))

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

-- File explorer
vim.keymap.set("n", "<leader>e", function()
  Snacks.explorer.reveal()
end, opts({ desc = "Reveal current file in explorer" }))

-- Don't replace yanked word
keymap("x", "<leader>p", [["_dP]], opts())
-- Normal paste
keymap("v", "p", '"_dP', opts())

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

-- Copy path
vim.keymap.set("n", "<leader>cp", function()
  vim.fn.setreg("+", vim.fn.expand("%:p:."))
end, opts({ desc = "Copy relative path" }))
vim.keymap.set("n", "<leader>cf", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, opts({ desc = "Copy full path" }))

-- `il` text object: inner line, trimmed of leading/trailing whitespace
-- Enables yil, vil, dil, cil, etc.
keymap("x", "il", "^og_", opts({ desc = "inner line (trimmed)" }))
keymap("o", "il", ":normal vil<CR>", opts({ desc = "inner line (trimmed)" }))

-- Replace word on current cursor
keymap(
  "n",
  "<leader>s",
  ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>",
  opts({ desc = "Replace current word" })
)

-- Navigate Neovim splits first, then cross the tmux/Kitty boundary at an edge.
local function navigate_window(direction, tmux_command, kitty_direction)
  if vim.env.TMUX and vim.env.TMUX ~= "" then
    vim.cmd(tmux_command)
    return
  end

  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(direction)
  if vim.api.nvim_get_current_win() ~= previous_window or not vim.env.KITTY_WINDOW_ID then
    return
  end

  vim.system({ "kitty", "@", "focus-window", "--match", "neighbor:" .. kitty_direction }, { detach = true })
end

vim.keymap.set("n", "<C-h>", function()
  navigate_window("h", "TmuxNavigateLeft", "left")
end, opts())
vim.keymap.set("n", "<C-j>", function()
  navigate_window("j", "TmuxNavigateDown", "bottom")
end, opts())
vim.keymap.set("n", "<C-k>", function()
  navigate_window("k", "TmuxNavigateUp", "top")
end, opts())
vim.keymap.set("n", "<C-l>", function()
  navigate_window("l", "TmuxNavigateRight", "right")
end, opts())

-- trouble
keymap(
  "n",
  "<leader>xx",
  ":Trouble diagnostics toggle<cr>",
  opts({ desc = "Toggle trouble view", noremap = true, silent = true })
)

keymap("n", "<C-e>", ":Legendary<cr>", opts({ desc = "Open legendary menu", noremap = true, silent = true }))

keymap("n", "<leader>tc", ":GoCoverage -p<cr>", opts({ desc = "Run go coverage" }))
vim.keymap.set("n", "<leader>gv", function()
  vim.cmd("GoModTidy")
  vim.cmd("GoModVendor")
end)
keymap("n", "<leader>to", ":GoAlt<cr>", opts({ desc = "Switch between go and test file" }))

-- neo-clip
keymap("n", "<leader>fy", ":lua require('neoclip.fzf')()<cr>", opts({ desc = "View yank history" }))

keymap("n", "<leader>cc", ":CodeCompanionChat Toggle<cr>", opts({ desc = "Toggle code companion" }))

vim.api.nvim_create_user_command("OpenInFinder", function()
  local file = vim.fn.expand("%:p") -- full path of current file
  if file == "" then
    print("No file to open in Finder")
    return
  end
  -- Use macOS 'open -R' to reveal the file in Finder
  vim.fn.jobstart({ "open", "-R", file }, { detach = true })
end, {})

keymap("n", "<leader>gd", ":DiffviewOpen<cr>", opts({ desc = "Diffview" }))
