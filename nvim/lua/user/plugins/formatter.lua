return {
	"mhartington/formatter.nvim",
	config = function()
		require("formatter").setup({
			logging = false,
			filetype = {
				["*"] = { require("formatter.filetypes.any").remove_trailing_whitespace },
				hcl = { require("formatter.filetypes.terraform").terraformfmt },
				lua = { require("formatter.filetypes.lua").stylua },
			},
		})

		vim.api.nvim_create_autocmd({ "BufWritePost" }, { command = "FormatWriteLock" })
	end,
}
