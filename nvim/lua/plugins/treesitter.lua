--treesitter
return {
    "nvim-treesitter/nvim-treesitter",
    name = "treesitter",
    run = ":TSUpdate",
    config = function()
        local configs = require("nvim-treesitter.configs")
        configs.setup({
            --autotag = { enable = true },
            ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "javascript", "html", "typescript" },
            sync_install = false,
            auto_install = true,
            highlight = { enable = true, additional_vim_regex_highlighting = false },
            indent = { enable = true }
        })
    end,
}
