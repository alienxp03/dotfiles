local slim_group = vim.api.nvim_create_augroup("SlimGroup", { clear = true })
local patterns = {
  { pattern = "*.html.erb", filetype = "eruby" },
  { pattern = "*.js.erb", filetype = "javascript.html" },
  { pattern = "*.jmx", filetype = "xml" },
  { pattern = ".env,.env.*,*.zsh,*.zshrc,*.tmux.conf,*.sh,*.helmignore", filetype = "bash" },
  -- Terraform
  { pattern = "*.hcl,*.terraformrc,*.terraform.rc,*.tf,*.tfvars,*.tfstate,*.tfstate.backup", filetype = "hcl" },
}

for _, config in pairs(patterns) do
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = config.pattern,
    command = ":set filetype=" .. config.filetype,
    group = slim_group,
  })
end
