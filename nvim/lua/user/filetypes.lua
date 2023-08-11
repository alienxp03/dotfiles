local slim_group = vim.api.nvim_create_augroup('SlimGroup', { clear = true })
local patterns = {
  { pattern = "*.html.erb", filetype = "eruby.html" },
  { pattern = "*.js.erb", filetype = "javascript.html" },
  { pattern = "*.jmx", filetype = "xml" },
  { pattern = "*.zsh,*.zshrc", filetype = "bash" },
  -- Terraform
  { pattern = "*.hcl", filetype = "hcl" },
  { pattern = ".terraformrc,.terraform.rc", filetype = "hcl" },
  { pattern = "*.tf,*.tfvars", filetype = "hcl" },
  { pattern = "*.tfstate,*.tfstate.backup", filetype = "hcl" },
}

for _, config in pairs(patterns) do
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = config.pattern,
    command = ":set filetype=" .. config.filetype,
    group = slim_group
  })
end

