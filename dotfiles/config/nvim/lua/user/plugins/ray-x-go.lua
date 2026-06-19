-- golang support
return {
  "ray-x/go.nvim",
  event = { "CmdlineEnter" },
  ft = { "go", "gomod" },
  build = ':lua require("go.install").update_all_sync()', -- if you need to install/update all binaries
  dependencies = { -- optional packages
    "ray-x/guihua.lua",
  },
  config = function()
    require("go").setup({
      gofmt = "gopls",
      build_tags = "-v -cover -race -count=1",
      run_in_floaterm = false,
    })
  end,
}
