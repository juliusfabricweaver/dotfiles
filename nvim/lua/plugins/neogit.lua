return {
  "NeogitOrg/neogit",
  name = "neogit",
  dependencies = {
    "nvim-lua/plenary.nvim", -- required

    -- Only one of these is needed, not both.
    "nvim-telescope/telescope.nvim", -- optional
    "ibhagwan/fzf-lua",            -- optional
  },
  keys = {
    {
      "<leader>ng",
      "<cmd>Neogit<cr>",
    }
  },
  config = true,
}
