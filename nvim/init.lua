require("set")
require("remap")
require("pack") -- installs and loads plugins (vim.pack)

-- Plugin configuration, in load order.
for _, name in ipairs({
  "gruvbox",
  "snacks",
  "treesitter",
  "render-markdown",
  "colorizer",
  "blink",
  "autopairs",
  "conform",
  "trouble",
  "fzf-lua",
  "review",
  "oil",
  "undotree",
  "gitsigns",
  "neogit",
  "diffview",
  "diffs",
  "lualine",
}) do
  require("plugins." .. name)
end

require("after")
