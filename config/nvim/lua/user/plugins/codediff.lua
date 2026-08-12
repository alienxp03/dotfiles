return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    {
      "<leader>gm",
      function()
        local origin_head = vim
          .system({ "git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" }, { text = true })
          :wait()
        local base = origin_head.code == 0 and vim.trim(origin_head.stdout) or nil

        if not base or base == "" then
          for _, candidate in ipairs({ "origin/main", "origin/master", "main", "master" }) do
            local result = vim.system({ "git", "rev-parse", "--verify", "--quiet", candidate }):wait()
            if result.code == 0 then
              base = candidate
              break
            end
          end
        end

        if not base then
          vim.notify("Could not find a main or master branch", vim.log.levels.ERROR)
          return
        end

        vim.cmd.CodeDiff(base .. "...")
      end,
      desc = "Compare branch with default branch",
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "codediff-explorer",
      callback = function(args)
        vim.schedule(function()
          for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
            vim.wo[win].foldenable = false
          end
        end)
      end,
    })
  end,
  opts = {
    explorer = {
      view_mode = "tree",
      auto_open_on_cursor = true,
    },
  },
}
