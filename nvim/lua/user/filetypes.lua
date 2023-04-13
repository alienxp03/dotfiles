local slim_group = vim.api.nvim_create_augroup('SlimGroup', { clear = true })
local patterns = {
  { pattern = "*.html.erb", filetype = "eruby.html" },
  { pattern = "*.js.erb", filetype = "javascript.html" },
}

for _, config in pairs(patterns) do
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = config.pattern,
    command = ":set filetype=" .. config.filetype,
    group = slim_group
  })
end

