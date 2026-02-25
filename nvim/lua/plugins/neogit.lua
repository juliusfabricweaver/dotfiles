return {
  "NeogitOrg/neogit",
  name = "neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
  },
  keys = {
    {
      "<leader>ng",
      "<cmd>Neogit<cr>",
    }
  },
  config = true,
}
