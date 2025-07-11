return {
  "navarasu/onedark.nvim",
  name = "onedark",
  priority = 1000,
  config = function()
    require("onedark").setup({
      style = "dark", -- Choose between 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer', 'light'
      transparent = false, -- Show/hide background
      term_colors = true, -- Change terminal color as per the selected theme style
      ending_tildes = false, -- Show the end-of-buffer tildes
      cmp_itemkind_reverse = false, -- Reverse item kind highlights in cmp menu

      -- Toggle theme style ---
      toggle_style_key = nil, -- Keybind to toggle theme style
      toggle_style_list = { "dark", "darker", "cool", "deep", "warm", "warmer", "light" }, -- Styles to toggle between

      -- Change code style ---
      code_style = {
        comments = "italic",
        keywords = "none",
        functions = "none",
        strings = "none",
        variables = "none",
      },

      -- Lualine options --
      lualine = {
        transparent = true, -- Lualine center bar transparency
      },

      -- Custom Highlights --
      colors = {}, -- Override default colors
      highlights = {}, -- Override highlight groups

      -- Plugins Config --
      diagnostics = {
        darker = true, -- Darker colors for diagnostics
        undercurl = false, -- Use undercurl instead of underline for diagnostics
        background = false, -- Use background color for virtual text
      },
    })
    require("onedark").load()
  end,
}

