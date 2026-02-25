return {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "L3MON4D3/LuaSnip",
    "rafamadriz/friendly-snippets",
  },
  event = "InsertEnter",
  opts = {
    keymap = {
      preset = "default",
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "cancel", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    },
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = "mono",
    },
    snippets = { preset = "luasnip" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    completion = {
      accept = { auto_brackets = { enabled = true } },
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      list = { selection = { preselect = true, auto_insert = true } },
    },
    signature = { enabled = true },
  },
}
