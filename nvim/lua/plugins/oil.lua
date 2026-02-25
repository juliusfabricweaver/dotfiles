return {
    'stevearc/oil.nvim',
    name = "oil",
    opts = {
        use_default_keymaps = true,
        keymaps = {
            ["<C-h>"] = false,
            ["<C-j>"] = false,
            ["<C-k>"] = false,
            ["<C-l>"] = false,
            ["g."] = "actions.toggle_hidden",
            ["<C-r>"] = "actions.refresh",
        },
        view_options = {
            show_hidden = true,
        }
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
}
