-- Draws the state into buffers: the page (one buffer, or two in split view),
-- the gutter (statuscolumn), the top bar (winbar) and the sidebar.
local api = vim.api
local S = require("review.state")
local diff = require("review.diff")

local M = {}

M.ns = api.nvim_create_namespace("review")
M.ns_syn = api.nvim_create_namespace("review_syntax")
M.ns_cur = api.nvim_create_namespace("review_current")

local function valid_buf(b)
  return b and api.nvim_buf_is_valid(b)
end

local function valid_win(w)
  return w and api.nvim_win_is_valid(w)
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

-- { {text, hl}, ... } -> text, { {col_start, col_end, hl} }
local function build(segs)
  local parts, marks, col = {}, {}, 0
  for i, seg in ipairs(segs) do
    parts[i] = seg[1]
    if seg[2] then
      marks[#marks + 1] = { col, col + #seg[1], seg[2] }
    end
    col = col + #seg[1]
  end
  return table.concat(parts), marks
end

local function ratio_bar(f)
  local total = f.added + f.removed
  if total == 0 then
    return 0, 0
  end
  local g = math.floor(5 * f.added / total + 0.5)
  if f.added > 0 then
    g = math.max(g, 1)
  end
  if f.removed > 0 then
    g = math.min(g, 4)
  end
  return g, 5 - g
end

local function header(f)
  local path = (f.old_path and f.old_path ~= f.path) and (f.old_path .. " → " .. f.path) or f.path
  local g, r = ratio_bar(f)
  local segs = {
    { path, f.viewed and "ReviewPathViewed" or "ReviewPath" },
    { "   +" .. f.added, "ReviewStatAdd" },
    { " −" .. f.removed, "ReviewStatDel" },
    { "  " },
    { string.rep("■", g), "ReviewStatAdd" },
    { string.rep("■", r), "ReviewStatDel" },
  }
  local note = f.status == "D" and "deleted" or (f.large and f.collapsed and "large diff") or nil
  if note then
    segs[#segs + 1] = { "   " .. note, "ReviewPathViewed" }
  end
  return build(segs)
end

-- The line object a line row shows on one side (nil = filler cell).
local function cell(row, side)
  if side == "unified" then
    return row.line
  end
  if side == "old" then
    return row.l
  end
  return row.r
end

local function row_text(row, side)
  local kind = row.kind
  if kind == "line" then
    local c = cell(row, side)
    return c and c.text or ""
  end
  if side == "new" or kind == "blank" then
    return ""
  end
  if kind == "header" then
    return header(row.file)
  elseif kind == "hunk" then
    return diff.hunk_text(row.hunk)
  elseif kind == "expander" then
    return row.text
  end
  return "  " .. row.text -- note
end

-- Which background a line cell gets on a given side.
local function cell_kind(c, side)
  if not c then
    return "filler"
  end
  if c.t == "+" and side ~= "old" then
    return "add"
  elseif c.t == "-" and side ~= "new" then
    return "del"
  end
  return "ctx"
end

local line_hl = { add = "ReviewAdd", del = "ReviewDel", filler = "ReviewFiller" }
local word_hl = { add = "ReviewAddWord", del = "ReviewDelWord" }

local function syntax_marks(buf, l, c, f, len)
  local syn = f.syn
  if not syn or not c then
    return
  end
  local caps = c.t == "-" and syn.old[c.old] or syn.new[c.new]
  if not caps then
    return
  end
  for i, cap in ipairs(caps) do
    local s = math.min(cap[1], len)
    local e = cap[2] < 0 and len or math.min(cap[2], len)
    if e > s then
      api.nvim_buf_set_extmark(buf, M.ns_syn, l, s, {
        end_col = e,
        hl_group = cap[3],
        priority = 100 + math.min(i, 90),
      })
    end
  end
end

local function decorate(buf, side, i, row, text, marks)
  local l, kind = i - 1, row.kind
  local function mark(col, opts)
    api.nvim_buf_set_extmark(buf, M.ns, l, col, opts)
  end
  if kind == "header" then
    mark(0, { line_hl_group = "ReviewFileHeader" })
    for _, m in ipairs(marks or {}) do
      mark(m[1], { end_col = m[2], hl_group = m[3] })
    end
    if side ~= "old" then
      local f = row.file
      mark(0, {
        virt_text = { { f.viewed and "☑ Viewed " or "☐ Viewed ", f.viewed and "ReviewViewedOn" or "ReviewViewedOff" } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  elseif kind == "hunk" or kind == "expander" then
    mark(0, { line_hl_group = "ReviewHunk" })
  elseif kind == "note" then
    mark(0, { line_hl_group = "ReviewNote" })
  elseif kind == "line" then
    local c = cell(row, side)
    local ck = cell_kind(c, side)
    if line_hl[ck] then
      mark(0, { line_hl_group = line_hl[ck] })
    end
    if c and c.words and word_hl[ck] then
      for _, w in ipairs(c.words) do
        if w[2] > w[1] and w[2] <= #text then
          mark(w[1], { end_col = w[2], hl_group = word_hl[ck], priority = 200 })
        end
      end
    end
    syntax_marks(buf, l, c, row.file, #text)
  end
end

local function sides(st)
  local list = {}
  for buf, side in pairs(st.side_of) do
    if valid_buf(buf) then
      list[#list + 1] = { buf, side }
    end
  end
  return list
end

--- Re-apply only the syntax colours of one file (after they were computed).
function M.apply_syntax(st, f)
  if not f.first_row or f.collapsed then
    return
  end
  for _, bs in ipairs(sides(st)) do
    local buf, side = bs[1], bs[2]
    api.nvim_buf_clear_namespace(buf, M.ns_syn, f.first_row - 1, f.last_row)
    for i = f.first_row, f.last_row do
      local row = st.rows[i]
      if row and row.kind == "line" then
        local c = cell(row, side)
        syntax_marks(buf, i - 1, c, f, c and #c.text or 0)
      end
    end
  end
end

-- Gutter -----------------------------------------------------------------------

local function num_width(st)
  local max = 0
  for _, f in ipairs(st.files) do
    local last = f.hunks[#f.hunks]
    if last then
      max = math.max(max, last.oend, last.nend, f.new_lines and #f.new_lines or 0)
    end
  end
  return math.max(3, #tostring(max))
end

local function pad(n, w)
  local s = n and tostring(n) or ""
  return string.rep(" ", w - #s) .. s
end

local lnum_hl = { add = "ReviewAddLnum", del = "ReviewDelLnum", ctx = "ReviewLnum", filler = "ReviewFiller" }
local sign_hl = { add = "ReviewAddSign", del = "ReviewDelSign", ctx = "Normal", filler = "ReviewFiller" }
local sign_ch = { add = "+", del = "-", ctx = " ", filler = " " }

--- 'statuscolumn' callback: old/new line numbers and the +/- sign.
function M.statuscolumn()
  local st = S.cur
  if not st or vim.v.virtnum ~= 0 then
    return ""
  end
  local side = st.side_of[api.nvim_win_get_buf(vim.g.statusline_winid)]
  local row = st.rows[vim.v.lnum]
  if not side or not row then
    return ""
  end
  local w = st.numw
  local numbers = side == "unified" and (2 * w + 3) or (w + 2)
  local kind = row.kind
  if kind == "line" then
    local c = cell(row, side)
    local ck = cell_kind(c, side)
    local nums
    if side == "unified" then
      nums = " " .. pad(c.old, w) .. " " .. pad(c.new, w) .. " "
    else
      nums = " " .. pad(c and (side == "old" and c.old or c.new) or nil, w) .. " "
    end
    return "%#" .. lnum_hl[ck] .. "#" .. nums .. "%#" .. sign_hl[ck] .. "#" .. sign_ch[ck] .. " "
  elseif kind == "header" then
    -- the fold marker sits at the far left, the path lines up with the code
    local fold = side == "new" and " " or (row.file.collapsed and "▸" or "▾")
    return "%#ReviewFold# " .. fold .. string.rep(" ", numbers)
  elseif kind == "hunk" or kind == "expander" then
    local arrow = side == "new" and " " or "↕"
    local left = math.floor((numbers - 1) / 2)
    return "%#ReviewHunkLnum#"
      .. string.rep(" ", left)
      .. arrow
      .. string.rep(" ", numbers - 1 - left)
      .. "%#ReviewHunk#  "
  end
  return "%#Normal#" .. string.rep(" ", numbers + 2)
end

-- Top bar ----------------------------------------------------------------------

local function esc(s)
  return (tostring(s):gsub("%%", "%%%%"))
end

local function totals(st)
  local added, removed, viewed = 0, 0, 0
  for _, f in ipairs(st.files) do
    added, removed = added + f.added, removed + f.removed
    viewed = viewed + (f.viewed and 1 or 0)
  end
  return added, removed, viewed
end

function M.winbars(st)
  local added, removed, viewed = totals(st)
  local n = #st.files
  local left = table.concat({
    "%#ReviewBarStrong# ",
    esc(st.base_ref),
    "%#ReviewBar# ← %#ReviewBarStrong#",
    esc(st.branch),
    "%#ReviewBar#    ",
    n,
    n == 1 and " file changed  " or " files changed  ",
    "%#ReviewStatAdd#+",
    added,
    " %#ReviewStatDel#−",
    removed,
    "%#ReviewBar#",
  })
  local right = ("%%#ReviewBarStrong#%d / %d%%#ReviewBar# viewed "):format(viewed, n)
  if valid_win(st.rwin) then
    vim.wo[st.win].winbar = left
    vim.wo[st.rwin].winbar = "%=" .. right
  elseif valid_win(st.win) then
    vim.wo[st.win].winbar = left .. "%=" .. right
  end
  if valid_win(st.swin) then
    vim.wo[st.swin].winbar = "%#ReviewBar# Files changed"
  end
end

-- Sidebar ----------------------------------------------------------------------

local function devicon(name)
  local ok, icons = pcall(require, "nvim-web-devicons")
  if not ok then
    return nil
  end
  return icons.get_icon(name, name:match("%.([^.]+)$"), { default = true })
end

function M.sidebar(st)
  local buf = st.sbuf
  if not valid_buf(buf) then
    return
  end
  local lines, all = {}, {}
  for i, e in ipairs(st.tree) do
    local indent = string.rep("  ", e.depth)
    if e.file then
      local f = e.file
      local segs = { { indent }, { f.viewed and "✓ " or "  ", "ReviewTreeCheck" } }
      local icon, icon_hl = devicon(e.name)
      if icon then
        segs[#segs + 1] = { icon .. " ", f.viewed and "ReviewTreeViewed" or icon_hl }
      end
      segs[#segs + 1] = { e.name, f.viewed and "ReviewTreeViewed" or nil }
      lines[i], all[i] = build(segs)
    else
      lines[i], all[i] = build({ { indent }, { "▾ " .. e.name, "ReviewTreeDir" } })
    end
  end
  set_lines(buf, lines)
  api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  for i, marks in ipairs(all) do
    for _, m in ipairs(marks) do
      api.nvim_buf_set_extmark(buf, M.ns, i - 1, m[1], { end_col = m[2], hl_group = m[3] })
    end
    local f = st.tree[i].file
    if f then
      api.nvim_buf_set_extmark(buf, M.ns, i - 1, 0, {
        virt_text = { { " " .. f.status .. " ", "ReviewStatus" .. f.status } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    end
  end
  st.sidebar_current = nil
end

--- Highlight the sidebar row of the file the page cursor is in.
function M.mark_current(st, f)
  local buf = st.sbuf
  if not valid_buf(buf) or st.sidebar_current == f then
    return
  end
  st.sidebar_current = f
  api.nvim_buf_clear_namespace(buf, M.ns_cur, 0, -1)
  for i, e in ipairs(st.tree) do
    if e.file == f then
      api.nvim_buf_set_extmark(buf, M.ns_cur, i - 1, 0, { line_hl_group = "ReviewTreeCurrent" })
      if valid_win(st.swin) and api.nvim_get_current_win() ~= st.swin then
        api.nvim_win_set_cursor(st.swin, { i, 0 })
      end
      return
    end
  end
end

-- Page -------------------------------------------------------------------------

--- Rebuild rows from the files and redraw everything. Cursor placement is the
--- caller's job.
function M.page(st)
  st.rows = diff.rows(st.files, st.view)
  st.numw = num_width(st)
  local empty = #st.rows == 0
  for _, bs in ipairs(sides(st)) do
    local buf, side = bs[1], bs[2]
    local lines, marks = {}, {}
    for i, row in ipairs(st.rows) do
      lines[i], marks[i] = row_text(row, side)
    end
    if empty then
      lines = { side == "new" and "" or ("  No changes against " .. st.base_ref) }
    end
    set_lines(buf, lines)
    api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    api.nvim_buf_clear_namespace(buf, M.ns_syn, 0, -1)
    for i, row in ipairs(st.rows) do
      decorate(buf, side, i, row, lines[i], marks[i])
    end
  end
  M.winbars(st)
  M.sidebar(st)
end

return M
