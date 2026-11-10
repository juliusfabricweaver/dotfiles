-- Highlight groups, derived from the active colourscheme rather than hardcoded.
local M = {}

local function split(n)
  return bit.rshift(n, 16), bit.band(bit.rshift(n, 8), 0xff), bit.band(n, 0xff)
end

--- Mix `alpha` of colour `a` into colour `b`.
local function blend(a, b, alpha)
  local ar, ag, ab = split(a)
  local br, bg, bb = split(b)
  local function mix(x, y)
    return math.floor(x * alpha + y * (1 - alpha) + 0.5)
  end
  return mix(ar, br) * 65536 + mix(ag, bg) * 256 + mix(ab, bb)
end

local function color(names, attr, fallback)
  for _, name in ipairs(names) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl[attr] then
      return hl[attr]
    end
  end
  return fallback
end

function M.setup()
  local dark = vim.o.background ~= "light"
  local bg = color({ "Normal" }, "bg", dark and 0x282828 or 0xfbf1c7)
  local fg = color({ "Normal" }, "fg", dark and 0xebdbb2 or 0x3c3836)
  local green = color({ "GruvboxGreen", "Added", "DiffAdded" }, "fg", 0xb8bb26)
  local red = color({ "GruvboxRed", "Removed", "DiffRemoved" }, "fg", 0xfb4934)
  local blue = color({ "GruvboxBlue", "Function" }, "fg", 0x83a598)
  local yellow = color({ "GruvboxYellow", "WarningMsg" }, "fg", 0xfabd2f)
  local dim = color({ "Comment" }, "fg", 0x928374)

  local add_bg, del_bg = blend(green, bg, 0.15), blend(red, bg, 0.15)
  local hunk_bg = blend(blue, bg, 0.15)
  local header_bg = blend(fg, bg, 0.09)

  local groups = {
    ReviewAdd = { bg = add_bg },
    ReviewDel = { bg = del_bg },
    ReviewAddWord = { bg = blend(green, bg, 0.40) },
    ReviewDelWord = { bg = blend(red, bg, 0.40) },
    ReviewAddLnum = { fg = fg, bg = blend(green, bg, 0.30) },
    ReviewDelLnum = { fg = fg, bg = blend(red, bg, 0.30) },
    ReviewAddSign = { fg = green, bg = add_bg },
    ReviewDelSign = { fg = red, bg = del_bg },
    ReviewLnum = { fg = dim, bg = bg },
    ReviewFiller = { bg = blend(fg, bg, 0.04) },
    ReviewHunk = { fg = dim, bg = hunk_bg },
    ReviewHunkLnum = { fg = blue, bg = blend(blue, bg, 0.30) },
    ReviewFileHeader = { bg = header_bg },
    ReviewFold = { fg = dim, bg = header_bg },
    ReviewPath = { fg = fg, bg = header_bg, bold = true },
    ReviewPathViewed = { fg = dim, bg = header_bg },
    ReviewNote = { fg = dim, italic = true },
    ReviewStatAdd = { fg = green },
    ReviewStatDel = { fg = red },
    ReviewViewedOff = { fg = dim, bg = header_bg },
    ReviewViewedOn = { fg = green, bg = header_bg },
    ReviewBar = { fg = dim },
    ReviewBarStrong = { fg = fg, bold = true },
    ReviewTreeDir = { fg = blue },
    ReviewTreeViewed = { fg = dim },
    ReviewTreeCheck = { fg = green },
    ReviewTreeCurrent = { bg = blend(fg, bg, 0.12) },
    ReviewStatusM = { fg = yellow },
    ReviewStatusA = { fg = green },
    ReviewStatusD = { fg = red },
    ReviewStatusR = { fg = blue },
  }
  for name, spec in pairs(groups) do
    spec.default = true
    vim.api.nvim_set_hl(0, name, spec)
  end
end

return M
