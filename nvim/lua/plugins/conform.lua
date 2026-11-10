require("conform").setup({
  formatters_by_ft = {
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    vue = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    lua = { "stylua" },
    php = { "php_cs_fixer" },
  },
  format_on_save = false,
})

-- normal mode only: visual-mode <leader>p stays clipboard paste (lua/remap.lua)
vim.keymap.set("n", "<leader>p", function()
  require("conform").format({ async = true })
end, { desc = "Format buffer" })
