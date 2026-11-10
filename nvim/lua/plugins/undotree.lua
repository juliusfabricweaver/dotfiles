-- Undo tree bundled with Neovim 0.12 (replaces mbbill/undotree).
vim.cmd.packadd("nvim.undotree")

-- opens the tree, or closes it if already open
vim.keymap.set("n", "<leader>u", function()
  require("undotree").open()
end, { desc = "Toggle undo tree" })
