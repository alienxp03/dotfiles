return {
  "mason-org/mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
  config = function()
    require("mason").setup()
  end,
}
