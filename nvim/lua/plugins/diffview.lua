return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gs", "<cmd>DiffviewOpen<CR>", desc = "Git diff view" },
    { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
  },
  opts = {},
}
