-- Plugins, managed by the built-in vim.pack (Neovim 0.12+).
--   update:  :lua vim.pack.update()      (review, then :write to confirm)
--   remove:  delete the line below, restart, :lua vim.pack.del({ "name" })
-- Versions actually installed are recorded in nvim-pack-lock.json.

-- Build hooks. Must be registered before vim.pack.add().
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("user_pack_hooks", { clear = true }),
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == "nvim-treesitter" and kind == "update" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      -- rebuild parsers against the updated plugin (was `build = ":TSUpdate"`)
      pcall(function()
        require("nvim-treesitter").update()
      end)
    end
  end,
})

local function gh(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  -- colourscheme and UI base
  gh("ellisonleao/gruvbox.nvim"),
  gh("folke/snacks.nvim"),

  -- libraries other plugins need
  gh("nvim-lua/plenary.nvim"),
  gh("nvim-tree/nvim-web-devicons"),

  -- syntax
  { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" },
  gh("MeanderingProgrammer/render-markdown.nvim"),
  gh("catgoose/nvim-colorizer.lua"),

  -- completion and snippets
  gh("L3MON4D3/LuaSnip"),
  { src = gh("saghen/blink.cmp"), version = vim.version.range("1") },
  gh("windwp/nvim-autopairs"),

  -- LSP and formatting (LSP itself is configured in lua/after/lsp.lua)
  gh("williamboman/mason.nvim"),
  gh("williamboman/mason-lspconfig.nvim"),
  gh("neovim/nvim-lspconfig"),
  gh("stevearc/conform.nvim"),
  gh("folke/trouble.nvim"),

  -- files and navigation
  gh("ibhagwan/fzf-lua"),
  gh("stevearc/oil.nvim"),
  gh("mbbill/undotree"),
  gh("knubie/vim-kitty-navigator"), -- tells kitty IS_VIM=true so ctrl+hjkl reach nvim

  -- git
  gh("lewis6991/gitsigns.nvim"),
  gh("NeogitOrg/neogit"),
  gh("sindrets/diffview.nvim"),
  { src = gh("akinsho/git-conflict.nvim"), version = vim.version.range("*") },

  -- statusline
  gh("nvim-lualine/lualine.nvim"),
}, { confirm = false })
