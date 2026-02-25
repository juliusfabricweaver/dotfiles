return {
    {
        "williamboman/mason.nvim",
        name = "mason",
    },
    {
        "williamboman/mason-lspconfig.nvim",
        name = "mason-lspconfig",
    },
    {
        "neovim/nvim-lspconfig",
        name = "nvim-lspconfig",
    },
}

-- mason, mason-lspconfig, nvim-lspconfig
--  return {
--      {
--          "williamboman/mason.nvim",
--          name = "mason",
--          config = function()
--              require("mason").setup()
--          end,
--      },
--      {
--          "williamboman/mason-lspconfig.nvim",
--          name = "mason-lspconfig",
--          config = function()
--              require("mason-lspconfig").setup({
--                  ensure_installed = { "lua_ls", "ast_grep", "tsserver" },
--              })
--          end,
--      },
--      {
--          "neovim/nvim-lspconfig",
--          name = "nvim-lspconfig",
--          config = function()
--              local lspconfig = require("lspconfig")
--              lspconfig.lua_ls.setup({})
--              lspconfig.ast_grep.setup({})
--              lspconfig.tsserver.setup({})
--              vim.keymap.set("n", "<leader>d", vim.lsp.buf.hover, {})
--              vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
--              vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
--          end,
--      },
--  }
