return {
  "nvim-neo-tree/neo-tree.nvim",
  name = "neo-tree",
  config = function()
    vim.keymap.set("n", "<leader>gs", ":DiffviewOpen<CR>")
    vim.keymap.set("n", "<leader>gc", ":DiffviewClose<CR>")
  end
}
