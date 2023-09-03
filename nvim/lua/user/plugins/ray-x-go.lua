-- golang support
return   {
  "ray-x/go.nvim",
  event = {"CmdlineEnter"},
  ft = {"go", 'gomod'},
  build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  dependencies = {  -- optional packages
    "ray-x/guihua.lua",
  },
  config = function()
    require("go").setup({
      gofmt = "gopls",
      build_tags = "-v -cover -race -count=1",
      run_in_floaterm = true,
    })

    -- Run gofmt + goimport on save
    local format_sync_grp = vim.api.nvim_create_augroup("GoImport", {})
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "*.go",
      callback = function()
       require('go.format').goimport()
      end,
      group = format_sync_grp,
    })
  end,
}
