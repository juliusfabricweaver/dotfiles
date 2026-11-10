-- Treesitter colours for diff rows. The whole old and new file are parsed so a
-- hunk that starts mid-function or mid-string is still coloured correctly;
-- captures are then collected only for the lines the diff shows.
--
-- file.syn = { old = { [lnum] = { {col_start, col_end|-1, group} } }, new = ... }
local M = {}

local skip = { spell = true, nospell = true, conceal = true }
local MAX_BYTES = 400 * 1024

local function lang_for(f)
  local ok, ft = pcall(vim.filetype.match, { filename = f.path, contents = f.new_lines })
  if not ok or not ft then
    return false
  end
  local lang = vim.treesitter.language.get_lang(ft) or ft
  local ok2, added = pcall(vim.treesitter.language.add, lang)
  return (ok2 and added) and lang or false
end

local function collect(text, lang, needed, lo, hi)
  local out = {}
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  if not ok or not pcall(parser.parse, parser, true) then
    return out
  end
  parser:for_each_tree(function(tree, ltree)
    local tlang = ltree:lang()
    local okq, query = pcall(vim.treesitter.query.get, tlang, "highlights")
    if not okq or not query then
      return
    end
    for id, node in query:iter_captures(tree:root(), text, lo - 1, hi) do
      local name = query.captures[id]
      if name:sub(1, 1) ~= "_" and not skip[name] then
        local sr, sc, er, ec = node:range()
        local group = "@" .. name .. "." .. tlang
        for r = math.max(sr, lo - 1), math.min(er, hi - 1) do
          if needed[r + 1] then
            local list = out[r + 1]
            if not list then
              list = {}
              out[r + 1] = list
            end
            list[#list + 1] = { r == sr and sc or 0, r == er and ec or -1, group }
          end
        end
      end
    end
  end)
  return out
end

local function wanted(f, side)
  local needed, lo, hi = {}, math.huge, 0
  local groups = {}
  for _, h in ipairs(f.hunks) do
    groups[#groups + 1] = h.lines
  end
  for gi in pairs(f.open_gaps or {}) do
    groups[#groups + 1] = require("review.diff").gap_lines(f, gi)
  end
  for _, lines in ipairs(groups) do
    for _, l in ipairs(lines) do
      local n
      if side == "old" then
        n = l.t == "-" and l.old or nil
      else
        n = l.t ~= "-" and l.new or nil
      end
      if n then
        needed[n] = true
        lo, hi = math.min(lo, n), math.max(hi, n)
      end
    end
  end
  return needed, lo, hi
end

--- Fill f.syn from f.new_text and f.old_text (either may be missing).
function M.compute(f)
  f.syn = { old = {}, new = {} }
  if f.lang == nil then
    f.lang = lang_for(f)
  end
  if not f.lang then
    return
  end
  for _, side in ipairs({ "old", "new" }) do
    local text = side == "old" and f.old_text or f.new_text
    if text and #text <= MAX_BYTES then
      local needed, lo, hi = wanted(f, side)
      if hi > 0 then
        f.syn[side] = collect(text, f.lang, needed, lo, hi)
      end
    end
  end
end

return M
