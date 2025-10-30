--lualine
return {
	"nvim-lualine/lualine.nvim",
	name = "lualine",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("lualine").setup({
			options = {
				theme = "gruvbox",
			},
			sections = {
				lualine_c = { { "filename", path = 1 } },
        lualine_x = {'filetype'},
			},
		})
	end
}
