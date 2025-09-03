return {
  "supermaven-inc/supermaven-nvim",
  event = "InsertEnter",
  enabled = os.getenv("NVIM_DISABLE_AI") ~= "1",
  config = function()
    require("supermaven-nvim").setup({
      disable_keymaps = true,
    })
  end,
}
