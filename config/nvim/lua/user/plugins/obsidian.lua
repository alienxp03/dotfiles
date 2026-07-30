local vault = vim.env.OBSIDIAN_VAULT
local enabled = vault ~= nil and vault ~= "" and vim.fn.isdirectory(vim.fs.joinpath(vault, ".obsidian")) == 1

local function open_scratch()
  vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vault, "Scratch.md")))
end

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  enabled = enabled,
  cmd = { "Obsidian" },
  ft = { "markdown" },
  dependencies = { "folke/snacks.nvim" },
  init = function()
    vim.api.nvim_create_user_command("Scratch", open_scratch, { desc = "Open persistent Obsidian scratchpad" })
  end,
  keys = {
    { "<leader>ns", open_scratch, desc = "Open Obsidian scratchpad" },
    { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "New Obsidian note" },
    { "<leader>nf", "<cmd>Obsidian quick_switch<cr>", desc = "Find Obsidian note" },
    { "<leader>ng", "<cmd>Obsidian search<cr>", desc = "Search Obsidian notes" },
    { "<leader>nd", "<cmd>Obsidian today<cr>", desc = "Open Obsidian daily note" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "personal",
        path = vault,
      },
    },
    picker = {
      name = "snacks.picker",
    },
    note_id_func = function(title, dir)
      return require("obsidian.builtin").title_id(title, dir)
    end,
    new_notes_location = "notes_subdir",
    frontmatter = {
      enabled = false,
    },
    note = {
      template = vim.NIL,
    },
    daily_notes = {
      workdays_only = false,
    },
    ui = {
      enable = false,
    },
    footer = {
      enabled = false,
    },
    statusline = {
      enabled = false,
    },
  },
}
