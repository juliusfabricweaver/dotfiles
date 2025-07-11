--telescope
return {
  {
    "nvim-telescope/telescope.nvim",
    name = "telescope",
    tag = '0.1.6',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'BurntSushi/ripgrep'
    },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
      vim.keymap.set('n', '<leader>fs', builtin.live_grep, {})
      vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})
      vim.keymap.set("n", "<leader>fg", builtin.git_files, {})
    end
  },

  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build =
    'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build'
  },
  --{
  --  "nvim-telescope/telescope-ui-select.nvim",
  --  name = "ui-select",
  --  config = function()
  --    require("telescope").setup {
  --      extensions = {
  --        ["ui-select"] = {
  --          require("telescope.themes").get_dropdown {}
  --        }
  --      }
  --    }
  --    require("telescope").load_extension("ui-select")
  --  end
  --}
}
