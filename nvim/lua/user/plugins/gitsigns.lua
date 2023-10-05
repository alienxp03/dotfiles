return {
	"lewis6991/gitsigns.nvim",
	dependencies = {
		-- Add indentation guides even on blank lines
		"lukas-reineke/indent-blankline.nvim",
	},
	config = function()
		require("indent_blankline").setup({
			char = "┊",
			show_trailing_blankline_indent = false,
		})
		require("gitsigns").setup()
	end,
}
