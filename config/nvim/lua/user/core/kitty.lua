if not vim.env.KITTY_WINDOW_ID then
  return
end

local function set_editor_var(value)
  vim.api.nvim_ui_send("\x1b]1337;SetUserVar=in_editor=" .. value .. "\007")
end

vim.api.nvim_create_autocmd({ "VimEnter", "VimResume", "UIEnter" }, {
  group = vim.api.nvim_create_augroup("KittyEditorVar", { clear = true }),
  callback = function()
    set_editor_var("MQ==")
  end,
})

vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
  group = "KittyEditorVar",
  callback = function()
    set_editor_var("")
  end,
})
