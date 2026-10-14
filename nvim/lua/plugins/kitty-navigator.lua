return {
    "knubie/vim-kitty-navigator",
    name = "kitty-navigator",
    -- must load at startup: it tells kitty IS_VIM=true so ctrl+hjkl reach nvim
    lazy = false,
    -- the plugin defines <C-h>/<C-j>/<C-k>/<C-l> itself
}
