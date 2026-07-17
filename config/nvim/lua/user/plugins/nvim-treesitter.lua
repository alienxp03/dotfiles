-- Highlight, edit, and navigate code
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
    "nvim-treesitter/nvim-treesitter-context",
    "windwp/nvim-ts-autotag",
  },
  config = function()
    local treesitter = require("nvim-treesitter")
    local parsers = {
      "bash",
      "css",
      "go",
      "html",
      "java",
      "javascript",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "query",
      "ruby",
      "scss",
      "sql",
      "toml",
      "tsx",
      "typescript",
      "vim",
      "yaml",
    }

    treesitter.setup({})
    treesitter.install(parsers)

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
      callback = function(args)
        local language = vim.treesitter.language.get_lang(args.match)
        if language and vim.tbl_contains(treesitter.get_installed(), language) then
          vim.treesitter.start(args.buf, language)
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })

    require("nvim-treesitter-textobjects").setup({
      select = { lookahead = true },
      move = { set_jumps = true },
    })

    local select = require("nvim-treesitter-textobjects.select").select_textobject
    local select_keymaps = {
      aa = "@parameter.outer",
      ia = "@parameter.inner",
      af = "@function.outer",
      ["if"] = "@function.inner",
      ac = "@class.outer",
      ic = "@class.inner",
    }
    for key, capture in pairs(select_keymaps) do
      vim.keymap.set({ "x", "o" }, key, function()
        select(capture, "textobjects")
      end, { desc = "Select " .. capture })
    end

    local move = require("nvim-treesitter-textobjects.move")
    local move_keymaps = {
      ["]m"] = { move.goto_next_start, "@function.outer" },
      ["]]"] = { move.goto_next_start, "@class.outer" },
      ["]M"] = { move.goto_next_end, "@function.outer" },
      ["]["] = { move.goto_next_end, "@class.outer" },
      ["[m"] = { move.goto_previous_start, "@function.outer" },
      ["[["] = { move.goto_previous_start, "@class.outer" },
      ["[M"] = { move.goto_previous_end, "@function.outer" },
      ["[]"] = { move.goto_previous_end, "@class.outer" },
    }
    for key, mapping in pairs(move_keymaps) do
      vim.keymap.set({ "n", "x", "o" }, key, function()
        mapping[1](mapping[2], "textobjects")
      end, { desc = "Move to " .. mapping[2] })
    end

    local swap = require("nvim-treesitter-textobjects.swap")
    vim.keymap.set("n", "<leader>a", function()
      swap.swap_next("@parameter.inner")
    end, { desc = "Swap with next parameter" })
    vim.keymap.set("n", "<leader>A", function()
      swap.swap_previous("@parameter.inner")
    end, { desc = "Swap with previous parameter" })

    require("nvim-ts-autotag").setup({
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    })
  end,
}
