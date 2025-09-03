return {
  "mason-org/mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
  config = function()
    require("mason").setup()

    -- Ensure tools are installed
    local mason_registry = require("mason-registry")
    local tools = {
      -- LSP servers (handled by mason-lspconfig)
      -- Linters and formatters
      "jsonlint",
      "luacheck",
    }

    for _, tool in ipairs(tools) do
      local p = mason_registry.get_package(tool)
      if not p:is_installed() then
        p:install()
      end
    end
  end,
}
