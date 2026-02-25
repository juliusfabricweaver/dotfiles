return {
  "norcalli/nvim-colorizer.lua",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("colorizer").setup({
      "*", -- all filetypes
    }, {
      RGB = true,
      RRGGBB = true,
      names = false,
      RRGGBBAA = true,
      css = true,
      css_fn = true,
    })
  end,
}
