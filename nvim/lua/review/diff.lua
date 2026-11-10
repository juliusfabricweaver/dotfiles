-- Pure data: parse `git diff` output, word-level diffs, context expansion and
-- turning files into the flat list of rows that gets drawn.
--
-- file = { path, old_path, status = "M"|"A"|"D"|"R", binary, added, removed,
--          hash, hunks = { hunk }, new_lines?, new_text?, collapsed, viewed }
-- hunk = { ostart, oend, nstart, nend, ctx, text?, lines = { line } }
-- line = { t = " "|"+"|"-", text, old?, new?, words? = { {col_start, col_end} } }
local M = {}

local textdiff = (vim.text and vim.text.diff) or vim.diff

local function new_file(path)
  return { path = path, status = "M", binary = false, hunks = {}, added = 0, removed = 0 }
end

-- "a/some path b/some path" -> "some path" (only reliable when not renamed;
-- renames are corrected by the "rename to" line that follows).
local function header_path(rest)
  local n = (#rest - 5) / 2
  if n == math.floor(n) and n > 0 and rest:sub(3, 2 + n) == rest:sub(#rest - n + 1) then
    return rest:sub(3, 2 + n)
  end
  return rest:match("^a/(.-) b/") or rest
end

function M.parse(text)
  local lines = vim.split(text, "\n", { plain = true })
  local files, f, h = {}, nil, nil
  local rem_old, rem_new, cur_old, cur_new = 0, 0, 0, 0

  local function finish(last)
    if f then
      f.hash = vim.fn.sha256(table.concat(lines, "\n", f._first, last))
      f._first = nil
      files[#files + 1] = f
    end
  end

  for i, line in ipairs(lines) do
    if h and (rem_old > 0 or rem_new > 0) then
      local c, body = line:sub(1, 1), line:sub(2)
      if c == "+" then
        h.lines[#h.lines + 1] = { t = "+", text = body, new = cur_new }
        cur_new, rem_new, f.added = cur_new + 1, rem_new - 1, f.added + 1
      elseif c == "-" then
        h.lines[#h.lines + 1] = { t = "-", text = body, old = cur_old }
        cur_old, rem_old, f.removed = cur_old + 1, rem_old - 1, f.removed + 1
      elseif c ~= "\\" then
        h.lines[#h.lines + 1] = { t = " ", text = body, old = cur_old, new = cur_new }
        cur_old, cur_new, rem_old, rem_new = cur_old + 1, cur_new + 1, rem_old - 1, rem_new - 1
      end
    elseif line:sub(1, 11) == "diff --git " then
      finish(i - 1)
      f = new_file(header_path(line:sub(12)))
      f._first = i
      h = nil
    elseif f then
      local a, b, c, d, ctx = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@ ?(.*)$")
      if a then
        local ocount = b == "" and 1 or tonumber(b)
        local ncount = d == "" and 1 or tonumber(d)
        -- With a zero count git reports the line *before* the change.
        local ostart = tonumber(a) + (ocount == 0 and 1 or 0)
        local nstart = tonumber(c) + (ncount == 0 and 1 or 0)
        h = {
          ostart = ostart,
          oend = ostart + ocount - 1,
          nstart = nstart,
          nend = nstart + ncount - 1,
          ctx = ctx,
          text = line,
          lines = {},
        }
        f.hunks[#f.hunks + 1] = h
        rem_old, rem_new, cur_old, cur_new = ocount, ncount, ostart, nstart
      elseif line:find("^new file mode") then
        f.status = "A"
      elseif line:find("^deleted file mode") then
        f.status = "D"
      elseif line:find("^rename from ") then
        f.old_path = line:sub(13)
        f.status = "R"
      elseif line:find("^rename to ") then
        f.path = line:sub(11)
      elseif line:find("^Binary files ") or line:find("^GIT binary patch") then
        f.binary = true
      elseif line:find("^%+%+%+ b/") then
        f.path = (line:sub(7):gsub("\t$", ""))
      end
    end
  end
  finish(#lines)
  return files
end

--- A file git does not know about yet, shown as fully added.
function M.untracked(path, text, lines)
  local f = new_file(path)
  f.status = "A"
  f.hash = vim.fn.sha256(text or path)
  if not lines then
    f.binary = true
    return f
  end
  f.new_text, f.new_lines, f.added = text, lines, #lines
  if #lines > 0 then
    local h = { ostart = 1, oend = 0, nstart = 1, nend = #lines, ctx = "", lines = {} }
    h.text = ("@@ -0,0 +1,%d @@"):format(#lines)
    for i, l in ipairs(lines) do
      h.lines[i] = { t = "+", text = l, new = i }
    end
    f.hunks[1] = h
  end
  return f
end

-- Word-level diff ------------------------------------------------------------

local function tokens(s)
  local out, i = {}, 1
  while i <= #s do
    local a, b = s:find("^[%w_\128-\255]+", i)
    if not a then
      a, b = s:find("^%s+", i)
    end
    if not a then
      a, b = i, i
    end
    out[#out + 1] = { s:sub(a, b), a - 1, b }
    i = b + 1
  end
  return out
end

local function joined(toks)
  local parts = {}
  for i, t in ipairs(toks) do
    parts[i] = t[1]
  end
  return table.concat(parts, "\n") .. "\n"
end

-- Changed column ranges for one side, or nil when most of the line changed.
local function ranges(toks, hunks, si, ci, len)
  local out, changed = {}, 0
  for _, hk in ipairs(hunks) do
    local start, count = hk[si], hk[ci]
    if count > 0 then
      local c1, c2 = toks[start][2], toks[start + count - 1][3]
      changed = changed + (c2 - c1)
      local last = out[#out]
      if last and last[2] >= c1 then
        last[2] = c2
      else
        out[#out + 1] = { c1, c2 }
      end
    end
  end
  if len > 0 and changed / len > 0.6 then
    return nil
  end
  return out
end

local function pair_words(del, add)
  if del.text == add.text or #del.text > 500 or #add.text > 500 then
    return
  end
  local ta, tb = tokens(del.text), tokens(add.text)
  if #ta == 0 or #tb == 0 then
    return
  end
  local ok, hunks = pcall(textdiff, joined(ta), joined(tb), { result_type = "indices" })
  if not ok or type(hunks) ~= "table" then
    return
  end
  local ra = ranges(ta, hunks, 1, 2, #del.text)
  local rb = ranges(tb, hunks, 3, 4, #add.text)
  -- Only worth showing when the two lines are recognisably the same line.
  if ra and rb then
    del.words, add.words = ra, rb
  end
end

--- Pair removed/added lines in each change block and mark what differs.
function M.words(f)
  if f.words_done then
    return
  end
  f.words_done = true
  for _, h in ipairs(f.hunks) do
    local i, n = 1, #h.lines
    while i <= n do
      if h.lines[i].t == "-" then
        local d = i
        while i <= n and h.lines[i].t == "-" do
          i = i + 1
        end
        local a = i
        while i <= n and h.lines[i].t == "+" do
          i = i + 1
        end
        for k = 0, math.min(a - d, i - a) - 1 do
          pair_words(h.lines[d + k], h.lines[a + k])
        end
      else
        i = i + 1
      end
    end
  end
end

-- Hidden context ------------------------------------------------------------
--
-- A file with n hunks has n + 1 gaps of unchanged lines: gap i sits above
-- hunk i, gap n + 1 after the last hunk. A gap is either hidden or shown
-- (f.open_gaps). Hunks themselves are never modified, so showing a gap and
-- folding a hunk (h.folded) are independent of each other.

function M.gap_size(f, gi)
  if not f.new_lines or #f.hunks == 0 then
    return 0
  end
  local prev = f.hunks[gi - 1]
  if gi > #f.hunks then
    return math.max(0, #f.new_lines - prev.nend)
  end
  return math.max(0, f.hunks[gi].nstart - 1 - (prev and prev.nend or 0))
end

function M.gap_open(f, gi)
  return f.open_gaps ~= nil and f.open_gaps[gi] == true and M.gap_size(f, gi) > 0
end

--- The unchanged lines of gap `gi`, as line objects.
function M.gap_lines(f, gi)
  f.gap_cache = f.gap_cache or {}
  local lines = f.gap_cache[gi]
  if not lines then
    lines = {}
    local prev = f.hunks[gi - 1]
    local pn, po = prev and prev.nend or 0, prev and prev.oend or 0
    for k = 1, M.gap_size(f, gi) do
      lines[k] = { t = " ", text = f.new_lines[pn + k] or "", old = po + k, new = pn + k }
    end
    f.gap_cache[gi] = lines
  end
  return lines
end

--- Show every gap of the file, or hide them all again when they are all
--- shown already. Returns true (now shown), false (now hidden), or nil when
--- the file has no hidden lines at all.
function M.toggle_gaps(f)
  local any, all = false, true
  for gi = 1, #f.hunks + 1 do
    if M.gap_size(f, gi) > 0 then
      any = true
      all = all and M.gap_open(f, gi)
    end
  end
  if not any then
    return nil
  end
  f.open_gaps = {}
  if not all then
    for gi = 1, #f.hunks + 1 do
      f.open_gaps[gi] = true
    end
  end
  return not all
end

function M.hunk_text(h)
  if not h.text then
    h.text = ("@@ -%d,%d +%d,%d @@ %s"):format(
      h.ostart,
      h.oend - h.ostart + 1,
      h.nstart,
      h.nend - h.nstart + 1,
      h.ctx or ""
    )
  end
  return h.text
end

-- Rows -----------------------------------------------------------------------

-- row.kind: "blank" | "header" | "hunk" | "line" | "note" | "expander"
-- line rows carry `line` in unified view, and `l` / `r` (either may be nil,
-- meaning a filler cell) in split view.
function M.rows(files, view)
  local rows = {}
  local function push(row)
    rows[#rows + 1] = row
  end
  for fi, f in ipairs(files) do
    if fi > 1 then
      push({ kind = "blank", file = f })
    end
    push({ kind = "header", file = f })
    f.first_row = #rows
    if not f.collapsed then
      if f.binary then
        push({ kind = "note", file = f, text = "Binary file not shown" })
      elseif #f.hunks == 0 then
        push({ kind = "note", file = f, text = f.status == "R" and "File renamed without changes" or "No content changes" })
      else
        M.words(f)
        local unified = view == "unified"
        -- revealed context: plain rows that still belong to hunk `h` for folding
        local function push_gap(gi, h)
          for _, l in ipairs(M.gap_lines(f, gi)) do
            if unified then
              push({ kind = "line", file = f, hunk = h, gap = gi, line = l })
            else
              push({ kind = "line", file = f, hunk = h, gap = gi, l = l, r = l })
            end
          end
        end
        for hi, h in ipairs(f.hunks) do
          local open = M.gap_open(f, hi)
          if open then
            push_gap(hi, h)
          end
          -- with the gap above shown the code runs on without a @@ row,
          -- unless the hunk is folded and the row is all there is of it
          if h.folded or not open then
            push({ kind = "hunk", file = f, hunk = h, folded = h.folded })
          end
          if h.folded then
            -- nothing more
          elseif unified then
            for _, l in ipairs(h.lines) do
              push({ kind = "line", file = f, hunk = h, line = l })
            end
          else
            local i, n = 1, #h.lines
            while i <= n do
              local l = h.lines[i]
              if l.t == " " then
                push({ kind = "line", file = f, hunk = h, l = l, r = l })
                i = i + 1
              else
                local d = i
                while i <= n and h.lines[i].t == "-" do
                  i = i + 1
                end
                local a = i
                while i <= n and h.lines[i].t == "+" do
                  i = i + 1
                end
                for k = 0, math.max(a - d, i - a) - 1 do
                  push({
                    kind = "line",
                    file = f,
                    hunk = h,
                    l = d + k < a and h.lines[d + k] or nil,
                    r = a + k < i and h.lines[a + k] or nil,
                  })
                end
              end
            end
          end
        end
        local last = #f.hunks + 1
        local below = M.gap_size(f, last)
        if M.gap_open(f, last) then
          push_gap(last, f.hunks[#f.hunks])
        elseif below > 0 then
          push({ kind = "expander", file = f, hunk = f.hunks[#f.hunks], text = ("%d more lines"):format(below) })
        end
      end
    end
    f.last_row = #rows
  end
  return rows
end

return M
