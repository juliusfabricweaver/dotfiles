-- vim remaps
vim.g.mapleader = " "
vim.keymap.set("n", "-", "<CMD>Oil<CR>", {})
vim.keymap.set("n", "<leader>h", ":vs<CR>", {})
vim.keymap.set("n", "<leader>v", ":sv<CR>", {})
vim.keymap.set({"n", "v"}, "J", ")")
vim.keymap.set({"n", "v"}, "K", "(")

vim.opt.clipboard = "unnamedplus"
vim.keymap.set({"n", "v"}, "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set("n", "<leader>Y", '"+Y', { noremap = true, silent = true })
vim.keymap.set({"n", "v"}, "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set({"n", "v"}, "<leader>P", '"+P', { noremap = true, silent = true })
