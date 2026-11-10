-- Local plugin (lua/review/): GitHub "Files changed"-style diff viewer.
-- Keys inside the viewer: g? lists them.
require("review").setup({
  default_base = "develop",
})

vim.keymap.set("n", "<leader>gr", "<cmd>Review<CR>", { desc = "Review branch (GitHub style)" })
