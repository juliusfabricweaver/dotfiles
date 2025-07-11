--prettier
return {
	"MunifTanjim/prettier.nvim",
	name = "prettier",
	dependencies = { "neovim/nvim-lspconfig", "jose-elias-alvarez/null-ls.nvim" },
  keys={
    {
      mode = { 'n' },
      '<Leader>p',
      '<cmd>Prettier<cr>'
    }
  }
}
