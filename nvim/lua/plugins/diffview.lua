require("diffview").setup({})

vim.keymap.set("n", "<leader>gs", "<cmd>DiffviewOpen<CR>", { desc = "Git diff view" })
vim.keymap.set("n", "<leader>gc", "<cmd>DiffviewClose<CR>", { desc = "Close diff view" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", { desc = "File history" })
