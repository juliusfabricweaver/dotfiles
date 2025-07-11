--neotree
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys={
    {
      mode = { 'n' },
      '<Leader>tt',
      '<cmd>Neotree right<cr>'
    }
  },
  config = function()
    require('neo-tree').setup({
      default_component_configs = {
        filesystem = {
          follow_current_file = {
            enabled = true,        -- This will find and focus the file in the active buffer every time
            --               -- the current file is changed while the tree is open.
            leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
          },
        },
      },
    })
  end
}
