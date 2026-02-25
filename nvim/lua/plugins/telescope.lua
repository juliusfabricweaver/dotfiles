return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local fzf = require("fzf-lua")

    fzf.setup({
      "telescope",
      winopts = {
        height = 0.85,
        width = 0.80,
        preview = {
          layout = "flex",
        }
      },
      keymap = {
        fzf = {
          ["tab"]       = "up",
          ["shift-tab"] = "down",
        }
      }
    })

    vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
    vim.keymap.set("n", "<leader>fs", fzf.live_grep, { desc = "Live grep" })
    vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Buffers" })
    vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Help tags" })
    vim.keymap.set("n", "<leader>fg", fzf.git_files, { desc = "Git files" })
  end
}
