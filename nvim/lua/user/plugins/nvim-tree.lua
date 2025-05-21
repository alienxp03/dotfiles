-- File explorer
return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "b0o/nvim-tree-preview.lua", -- for file previews
  },
  config = function()
    require("nvim-tree").setup({
      view = { adaptive_size = true },
      update_focused_file = {
        enable = true,
        update_cwd = true,
      },
      renderer = {
        highlight_git = true,
        root_folder_modifier = ":t",
        icons = {
          glyphs = {
            default = "",
            symlink = "",
            folder = {
              arrow_open = "",
              arrow_closed = "",
              default = "",
              open = "",
              empty = "",
              empty_open = "",
              symlink = "",
              symlink_open = "",
            },
            git = {
              unstaged = "",
              staged = "S",
              unmerged = "",
              renamed = "➜",
              untracked = "U",
              deleted = "",
              ignored = "◌",
            },
          },
        },
      },
      hijack_directories = {
        auto_open = true,
      },
      diagnostics = {
        enable = true,
        show_on_dirs = true,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
      view = {
        width = 30,
        side = "left",
      },
      filters = {
        custom = { ".DS_Store" },
        dotfiles = false,
      },
      git = {
        ignore = false,
      },
      on_attach = function(bufnr)
        local api = require("nvim-tree.api")

        -- Important: When you supply an `on_attach` function, nvim-tree won't
        -- automatically set up the default keymaps. To set up the default keymaps,
        -- call the `default_on_attach` function. See `:help nvim-tree-quickstart-custom-mappings`.
        api.config.mappings.default_on_attach(bufnr)

        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        local preview = require("nvim-tree-preview")

        vim.keymap.set("n", "P", preview.watch, opts("Preview (Watch)"))
        vim.keymap.set("n", "<Esc>", preview.unwatch, opts("Close Preview/Unwatch"))

        -- Option A: Smart tab behavior: Only preview files, expand/collapse directories (recommended)
        vim.keymap.set("n", "<Tab>", function()
          local ok, node = pcall(api.tree.get_node_under_cursor)
          if ok and node then
            if node.type == "directory" then
              api.node.open.edit()
            else
              preview.node(node, { toggle_focus = true })
            end
          end
        end, opts("Preview"))

        -- Option B: Simple tab behavior: Always preview
        -- vim.keymap.set('n', '<Tab>', preview.node_under_cursor, opts 'Preview')
      end,
    })
  end,
}
