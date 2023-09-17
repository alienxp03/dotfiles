return {
	"romgrk/barbar.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"lewis6991/gitsigns.nvim",
	},
	config = function()
		require("barbar").setup({
			sidebar_filetypes = {
				NvimTree = true,
			},
		})
	end,
}
