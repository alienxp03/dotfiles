-- Highlight, edit, and navigate code
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
    "nvim-treesitter/nvim-treesitter-context",
    "windwp/nvim-ts-autotag",
  },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua",
        "ruby",
        "html",
        "javascript",
        "json",
        "bash",
        "css",
        "go",
        "java",
        "query",
        "scss",
        "sql",
        "typescript",
        "tsx",
        "vim",
        "toml",
        "yaml",
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
      autotag = {
        enable = true,
        filetypes = { "html", "slim", "xml" },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]m"] = "@function.outer",
            ["]]"] = "@class.outer",
          },
          goto_next_end = {
            ["]M"] = "@function.outer",
            ["]["] = "@class.outer",
          },
          goto_previous_start = {
            ["[m"] = "@function.outer",
            ["[["] = "@class.outer",
          },
          goto_previous_end = {
            ["[M"] = "@function.outer",
            ["[]"] = "@class.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>a"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>A"] = "@parameter.inner",
          },
        },
      },
    })

    -- nvim-treesitter's markdown injection directive still receives the old
    -- single-node capture shape, but Neovim 0.12 passes capture lists. Without
    -- this shim, opening markdown files can spam `attempt to call method
    -- 'range' (a nil value)` from vim.treesitter.get_node_text().
    if vim.fn.has("nvim-0.12") == 1 then
      local query = vim.treesitter.query
      local aliases = {
        ex = "elixir",
        pl = "perl",
        sh = "bash",
        uxn = "uxntal",
        ts = "typescript",
      }

      local function first_node(capture)
        if type(capture) == "table" then
          return capture[1]
        end
        return capture
      end

      query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
        local node = first_node(match[pred[2]])
        if not node or type(node.range) ~= "function" then
          return
        end

        local alias = vim.treesitter.get_node_text(node, bufnr):lower()
        metadata["injection.language"] = vim.filetype.match({ filename = "a." .. alias }) or aliases[alias] or alias
      end, { force = true, all = false })
    end

    require("nvim-ts-autotag").setup({
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    })
  end,
}
