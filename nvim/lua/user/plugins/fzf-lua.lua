return {
  "ibhagwan/fzf-lua", -- Fuzzy Finder (files, lsp, etc)
  config = function()
    require("fzf-lua").setup({
      bat = {
        cmd = "bat",
        args = "--color=always --style=numbers,changes",
      },
      previewers = {
        builtin = {
          ["hls.cursorline"] = "Search", -- cursor line highlight
          extensions = {
            ["png"] = { "chafa", "{file}" },
            ["svg"] = { "chafa", "{file}" },
            ["jpg"] = { "chafa", "{file}" },
          },
          syntax_limit_b = 1024 * 100, -- 100KB
        },
      },
      winopts = {
        height = 0.98,
        width = 0.98,
        preview = {
          -- horizontal = "right:75%",
          vertical = "down:75%",
          layout = "vertical",
          wrap = true,
        },
      },
      files = {
        formatter = "path.filename_first",
      },
      grep = {
        rg_opts = "--hidden --line-number --color=always --column -S -g '!{.git,node_modules}/*'",
        rg_glob_fn = function(query, opts)
          local regex, flags = query:match("^(.-)%s%-%-(.*)$")
          -- If no separator is detected will return the original query
          return (regex or query), flags
        end,
      },
    })
  end,
}
