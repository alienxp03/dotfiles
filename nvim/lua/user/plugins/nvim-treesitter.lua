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
      -- Add languages to be installed here that you want installed for treesitter
      ensure_installed = {
        "lua",
        "ruby",
        "html",
        "javascript",
        "json",
        "help",
        "bash",
        "css",
        "go",
        "java",
        "query",
        "scss",
        "sql",
        "vim",
        "yaml",
      },
      ignore_install = { "help" },
      auto_install = true,
      indent = { enable = true },
      -- autotag
      autotag = {
        enable = true,
        filetypes = { "html", "slim", "xml" },
      },
      highlight = {
        enable = true,
        -- Hardcoded to disable json for now. Ideally, disable it based on file size
        -- disable = { "json" },
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<c-space>",
          node_incremental = "<c-space>",
          scope_incremental = "<c-s>",
          node_decremental = "<c-backspace>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
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
          set_jumps = true, -- whether to set jumps in the jumplist
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
  end,
}
