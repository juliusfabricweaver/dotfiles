-- Review: a GitHub "Files changed"-style diff viewer.
--   :Review [branch]   compare the working tree against a branch (default: develop)
-- Design: docs/superpowers/specs/2026-11-10-review-diff-viewer-design.md
local api = vim.api
local S = require("review.state")
local async = require("review.async")
local git = require("review.git")
local diff = require("review.diff")
local render = require("review.render")
local store = require("review.store")
local syntax = require("review.syntax")
local tree = require("review.tree")
local hl = require("review.hl")

local M = {}
local A = {} -- actions bound to keys

local function notify(msg, level)
  vim.notify("Review: " .. msg, level or vim.log.levels.INFO)
end

local function valid_win(w)
  return w and api.nvim_win_is_valid(w)
end

local function valid_tab(t)
  return t and api.nvim_tabpage_is_valid(t)
end

-- State helpers ----------------------------------------------------------------

local function store_key(st)
  return st.branch .. " <- " .. st.base_ref
end

local function save_viewed(st)
  local map = {}
  for _, f in ipairs(st.files) do
    if f.viewed then
      map[f.path] = f.hash
    end
  end
  store.write(st.root, store_key(st), map)
end

--- Take freshly loaded files into the state, keeping the objects (folds,
--- expanded context, syntax) of files whose diff did not change.
--- Returns false when nothing changed at all.
local function adopt(st, data)
  local same_base = st.merge_base == data.merge_base and st.branch == data.branch
  local prev = {}
  for _, f in ipairs(st.files or {}) do
    prev[f.path] = f
  end
  st.branch, st.merge_base = data.branch, data.merge_base
  local viewed = store.read(st.root)[store_key(st)] or {}
  local changed = not same_base or #data.files ~= #(st.files or {})
  local files = {}
  for i, f in ipairs(data.files) do
    local old = prev[f.path]
    if same_base and old and old.hash == f.hash then
      files[i] = old
    else
      changed = true
      f.viewed = viewed[f.path] == f.hash
      f.large = f.added + f.removed > S.config.large_diff
      f.collapsed = f.viewed or f.status == "D" or f.large
      files[i] = f
    end
  end
  st.tree, st.files = tree.build(files)
  return changed
end

-- Syntax colours are computed in the background, one file at a time.
local function kick_syntax(st)
  if st.syn_running then
    return
  end
  st.syn_running = true
  async.run(function()
    local ok, err = pcall(function()
      while S.cur == st do
        local f
        for _, c in ipairs(st.files) do
          if not c.collapsed and not c.syn and not c.binary and #c.hunks > 0 then
            f = c
            break
          end
        end
        if not f then
          break
        end
        if f.old_text == nil and f.removed > 0 and f.status ~= "A" then
          f.old_text = git.exec(st.root, { "show", st.merge_base .. ":" .. (f.old_path or f.path) }) or false
        end
        syntax.compute(f)
        if S.cur == st and vim.tbl_contains(st.files, f) then
          render.apply_syntax(st, f)
        end
        async.yield()
      end
    end)
    st.syn_running = false
    if not ok then
      notify("syntax highlighting failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end)
end

-- Cursor and view --------------------------------------------------------------

--- The page window the user is in (left/unified unless they are in the right).
local function page_win(st)
  local cur = api.nvim_get_current_win()
  return cur == st.rwin and st.rwin or st.win
end

local function in_sidebar(st)
  return api.nvim_get_current_win() == st.swin
end

local function cursor_row(st)
  local win = page_win(st)
  if not valid_win(win) then
    return nil, 1
  end
  local lnum = api.nvim_win_get_cursor(win)[1]
  return st.rows[lnum], lnum
end

local function row_nums(row)
  if row.kind ~= "line" then
    return nil, nil
  end
  if row.line then
    return row.line.old, row.line.new
  end
  return row.l and row.l.old, row.r and row.r.new
end

--- Something that identifies the cursor's row across a redraw.
local function anchor_of(st)
  local row, lnum = cursor_row(st)
  local win = page_win(st)
  local offset = valid_win(win) and (lnum - vim.fn.line("w0", win)) or 0
  if not row then
    return { offset = offset }
  end
  local old, new = row_nums(row)
  return { path = row.file.path, kind = row.kind, hunk = row.hunk, old = old, new = new, offset = offset }
end

local function find_row(st, a)
  local f
  for _, c in ipairs(st.files) do
    if c.path == a.path then
      f = c
      break
    end
  end
  if not f or not f.first_row then
    return 1
  end
  if a.kind == "blank" then
    return math.max(1, f.first_row - 1)
  end
  local hunk_row
  for i = f.first_row + 1, f.last_row do
    local row = st.rows[i]
    if row.kind == a.kind and (a.kind == "hunk" or a.kind == "expander") and row.hunk == a.hunk then
      return i
    elseif row.kind == "line" and (a.new or a.old) then
      local old, new = row_nums(row)
      if (a.new and new == a.new) or (not a.new and old == a.old) then
        return i
      end
    elseif row.kind == "hunk" and row.hunk == a.hunk then
      hunk_row = i
    end
  end
  return hunk_row or f.first_row
end

--- Put the cursor on `lnum` with `topline` at the top, in both page windows.
local function set_view(st, lnum, topline)
  local total = math.max(1, #st.rows)
  lnum = math.max(1, math.min(lnum, total))
  for _, win in ipairs({ st.win, st.rwin }) do
    if valid_win(win) then
      api.nvim_win_set_cursor(win, { lnum, 0 })
      if topline then
        api.nvim_win_call(win, function()
          vim.fn.winrestview({ topline = math.max(1, math.min(topline, total)) })
        end)
      end
    end
  end
  local row = st.rows[lnum]
  if row then
    render.mark_current(st, row.file)
  end
end

--- Redraw, keeping the cursor on the same row at the same screen position.
local function redraw(st, anchor)
  anchor = anchor or anchor_of(st)
  render.page(st)
  local lnum = anchor.path and find_row(st, anchor) or 1
  set_view(st, lnum, lnum - (anchor.offset or 0))
  kick_syntax(st)
end

local function jump_to_file(st, f)
  if f and f.first_row then
    set_view(st, f.first_row, f.first_row)
  end
end

-- Windows ----------------------------------------------------------------------

local function make_buf(name)
  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_name, buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "review"
  return buf
end

local function common_opts(win)
  local o = vim.wo[win]
  o.wrap = false
  o.scrolloff = 0 -- so a file header can sit at the very top
  o.relativenumber = false
  o.signcolumn = "no"
  o.foldcolumn = "0"
  o.foldenable = false
  o.spell = false
  o.list = false
  o.colorcolumn = ""
  o.cursorline = false
end

local function page_opts(win, bound)
  common_opts(win)
  local o = vim.wo[win]
  o.number = true
  o.statuscolumn = "%!v:lua.require'review.render'.statuscolumn()"
  o.scrollbind = bound
  o.cursorbind = bound
end

local function sidebar_opts(win)
  common_opts(win)
  local o = vim.wo[win]
  o.number = false
  o.statuscolumn = ""
  o.cursorline = true
  o.winfixwidth = true
end

local set_keys

local function open_sidebar(st)
  if valid_win(st.swin) then
    return
  end
  if not (st.sbuf and api.nvim_buf_is_valid(st.sbuf)) then
    st.sbuf = make_buf("review://files")
    set_keys(st, st.sbuf)
  end
  st.swin = api.nvim_open_win(st.sbuf, false, {
    split = "left",
    win = st.win,
    width = S.config.sidebar_width,
  })
  sidebar_opts(st.swin)
end

local function create_ui(st)
  st.origin_tab = api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  local scratch = api.nvim_get_current_buf()
  st.tab = api.nvim_get_current_tabpage()
  st.win = api.nvim_get_current_win()
  st.buf = make_buf("review://page")
  api.nvim_win_set_buf(st.win, st.buf)
  pcall(api.nvim_buf_delete, scratch, { force = true })
  st.side_of = { [st.buf] = "unified" }
  page_opts(st.win, false)
  set_keys(st, st.buf)
  open_sidebar(st)
  api.nvim_create_autocmd("CursorMoved", {
    group = "review",
    buffer = st.buf,
    callback = function()
      local row = S.cur == st and cursor_row(st)
      if row then
        render.mark_current(st, row.file)
      end
    end,
  })
end

function M.close()
  local st = S.cur
  if not st then
    return
  end
  S.cur = nil
  if valid_tab(st.tab) then
    if #api.nvim_list_tabpages() == 1 then
      vim.cmd("tabnew")
    end
    pcall(vim.cmd, "tabclose " .. api.nvim_tabpage_get_number(st.tab))
  end
  for _, buf in ipairs({ st.buf, st.rbuf, st.sbuf }) do
    if buf and api.nvim_buf_is_valid(buf) then
      pcall(api.nvim_buf_delete, buf, { force = true })
    end
  end
  if valid_tab(st.origin_tab) then
    api.nvim_set_current_tabpage(st.origin_tab)
  end
end

-- Loading ----------------------------------------------------------------------

--- (async) Resolve the base to compare against; nil + message on failure.
local function resolve_base(root, name)
  if name and name ~= "" then
    local ref = git.resolve(root, name)
    if not ref then
      return nil, "no branch named '" .. name .. "'"
    end
    return ref
  end
  local ref = git.resolve(root, S.config.default_base)
  if ref then
    return ref
  end
  for _, fallback in ipairs(S.config.fallback_bases) do
    ref = git.resolve(root, fallback)
    if ref then
      notify(("no '%s' branch here, comparing against %s"):format(S.config.default_base, ref))
      return ref
    end
  end
  return nil, "no base branch found (tried " .. S.config.default_base .. ", " .. table.concat(S.config.fallback_bases, ", ") .. ")"
end

--- Reload the open review. opts.force redraws even when nothing changed.
local function reload(st, opts)
  opts = opts or {}
  if st.loading then
    return
  end
  st.loading = true
  async.run(function()
    local data, err = git.load(st.root, st.base_ref)
    st.loading = false
    if S.cur ~= st or not valid_tab(st.tab) then
      return
    end
    if not data then
      notify(err or "git diff failed", vim.log.levels.ERROR)
      return
    end
    local anchor = anchor_of(st)
    if adopt(st, data) or opts.force then
      redraw(st, opts.top and {} or anchor)
    end
  end)
end

--- Open a review against `base` (nil = the default base).
function M.open(base)
  async.run(function()
    local buf_dir = vim.fs.dirname(api.nvim_buf_get_name(0))
    local root = (buf_dir and vim.uv.fs_stat(buf_dir)) and git.root(buf_dir) or nil
    root = root or git.root(vim.fn.getcwd())
    if not root then
      notify("not inside a git repository", vim.log.levels.ERROR)
      return
    end

    local st = S.cur
    if st and valid_tab(st.tab) and st.root == root then
      -- Already open for this repo: focus it, switch base if one was given.
      api.nvim_set_current_tabpage(st.tab)
      if base and base ~= "" then
        local ref, err = resolve_base(root, base)
        if not ref then
          notify(err, vim.log.levels.ERROR)
          return
        end
        st.base_ref = ref
        reload(st, { force = true, top = true })
      end
      return -- (entering the tab already reloads)
    end

    local ref, err = resolve_base(root, base)
    if not ref then
      notify(err, vim.log.levels.ERROR)
      return
    end
    local data, lerr = git.load(root, ref)
    if not data then
      notify(lerr or "git diff failed", vim.log.levels.ERROR)
      return
    end
    if #data.files == 0 then
      notify("No changes against " .. ref)
      return
    end

    M.close()
    hl.setup()
    st = { root = root, base_ref = ref, view = "unified", rows = {}, files = {} }
    adopt(st, data)
    create_ui(st)
    S.cur = st
    redraw(st, {})
  end)
end

-- Actions ----------------------------------------------------------------------

--- The file an action applies to: under the sidebar cursor, or the page cursor.
local function target_file(st)
  if in_sidebar(st) then
    local e = st.tree[api.nvim_win_get_cursor(st.swin)[1]]
    return e and e.file
  end
  local row = cursor_row(st)
  return row and row.file
end

local function next_file(st, f)
  for i, c in ipairs(st.files) do
    if c == f then
      return st.files[i + 1]
    end
  end
end

function A.toggle_viewed(st)
  local f = target_file(st)
  if not f then
    return
  end
  f.viewed = not f.viewed
  f.collapsed = f.viewed
  save_viewed(st)
  if in_sidebar(st) then
    redraw(st)
    return
  end
  render.page(st)
  if f.viewed then
    -- Like GitHub: the file folds away and the next one slides up under it.
    local nxt = next_file(st, f) or f
    set_view(st, nxt.first_row, f.first_row)
  else
    set_view(st, f.first_row, f.first_row)
  end
  kick_syntax(st)
end

function A.toggle_fold(st)
  local f = target_file(st)
  if not f then
    return
  end
  f.collapsed = not f.collapsed
  if in_sidebar(st) then
    redraw(st)
    return
  end
  local a = anchor_of(st)
  redraw(st, { path = f.path, kind = "header", offset = math.min(a.offset, 3) })
end

local function step_file(st, dir)
  local _, lnum = cursor_row(st)
  local target
  for _, f in ipairs(st.files) do
    if dir > 0 and f.first_row > lnum then
      target = f
      break
    elseif dir < 0 and f.first_row < lnum then
      target = f
    end
  end
  jump_to_file(st, target)
end

function A.next_file(st)
  step_file(st, 1)
end

function A.prev_file(st)
  step_file(st, -1)
end

local function step_hunk(st, dir)
  local _, lnum = cursor_row(st)
  local i = lnum + dir
  while st.rows[i] do
    if st.rows[i].kind == "hunk" then
      set_view(st, i)
      return
    end
    i = i + dir
  end
end

function A.next_hunk(st)
  step_hunk(st, 1)
end

function A.prev_hunk(st)
  step_hunk(st, -1)
end

local function expand(st, count)
  local row = cursor_row(st)
  if not row or not row.hunk then
    return
  end
  local f, a = row.file, anchor_of(st)
  local first, hunk
  if row.kind == "expander" then
    first, hunk = diff.expand_below(f, count)
    a.hunk = hunk
  else
    local hi
    for i, h in ipairs(f.hunks) do
      if h == row.hunk then
        hi = i
      end
    end
    first, hunk = diff.expand_above(f, hi, count)
    if first then
      -- Stay on the hunk bar while it exists, so the key can be repeated.
      a = { path = f.path, kind = "hunk", hunk = hunk, new = first, offset = a.offset }
      if hunk ~= row.hunk then
        a.kind = "line"
      end
    end
  end
  if not first then
    notify(f.new_lines and "nothing more to expand here" or "context is not available for this file")
    return
  end
  if f.syn then
    syntax.compute(f)
  end
  redraw(st, a)
end

function A.expand(st)
  expand(st, S.config.context_step)
end

function A.expand_all(st)
  expand(st, nil)
end

function A.toggle_view(st)
  local anchor = anchor_of(st)
  if st.view == "unified" then
    st.view = "split"
    if not (st.rbuf and api.nvim_buf_is_valid(st.rbuf)) then
      st.rbuf = make_buf("review://new")
      set_keys(st, st.rbuf)
    end
    st.rwin = api.nvim_open_win(st.rbuf, false, { split = "right", win = st.win })
    st.side_of = { [st.buf] = "old", [st.rbuf] = "new" }
    page_opts(st.win, true)
    page_opts(st.rwin, true)
  else
    st.view = "unified"
    local rwin = st.rwin
    st.rwin = nil
    if api.nvim_get_current_win() == rwin then
      api.nvim_set_current_win(st.win)
    end
    if valid_win(rwin) then
      api.nvim_win_close(rwin, true)
    end
    st.side_of = { [st.buf] = "unified" }
    page_opts(st.win, false)
  end
  if valid_win(st.swin) then
    api.nvim_win_set_width(st.swin, S.config.sidebar_width)
  end
  vim.cmd("wincmd =")
  redraw(st, anchor)
end

function A.toggle_sidebar(st)
  if valid_win(st.swin) then
    if api.nvim_get_current_win() == st.swin then
      api.nvim_set_current_win(st.win)
    end
    api.nvim_win_close(st.swin, true)
    st.swin = nil
  else
    open_sidebar(st)
    render.sidebar(st)
    render.winbars(st)
    local row = cursor_row(st)
    if row then
      render.mark_current(st, row.file)
    end
  end
end

local function pick(items, prompt, on_choice)
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(items, {
      prompt = prompt .. "> ",
      actions = {
        ["enter"] = function(selected)
          if selected and selected[1] then
            on_choice(selected[1])
          end
        end,
      },
    })
  else
    vim.ui.select(items, { prompt = prompt }, function(choice)
      if choice then
        on_choice(choice)
      end
    end)
  end
end

function A.pick_base(st)
  async.run(function()
    local branches = git.branches(st.root)
    vim.schedule(function()
      pick(branches, "Compare against", function(name)
        vim.schedule(function()
          M.open(name)
        end)
      end)
    end)
  end)
end

function A.pick_file(st)
  local paths = {}
  for i, f in ipairs(st.files) do
    paths[i] = f.path
  end
  pick(paths, "Changed files", function(path)
    vim.schedule(function()
      for _, f in ipairs(st.files) do
        if f.path == path and S.cur == st then
          api.nvim_set_current_win(st.win)
          jump_to_file(st, f)
        end
      end
    end)
  end)
end

--- Enter: in the sidebar go to that file on the page, on the page open the
--- real file at that line.
function A.enter(st)
  if in_sidebar(st) then
    local f = target_file(st)
    if f then
      api.nvim_set_current_win(st.win)
      jump_to_file(st, f)
    end
    return
  end
  local row, lnum = cursor_row(st)
  if not row then
    return
  end
  local f = row.file
  if f.status == "D" then
    notify(f.path .. " was deleted, there is no file to open")
    return
  end
  local _, target = row_nums(row)
  if not target and row.kind == "line" then
    -- a removed line: the nearest line that still exists
    for i = lnum + 1, f.last_row do
      local _, new = row_nums(st.rows[i])
      if new then
        target = new
        break
      end
    end
  end
  target = target or (row.hunk and row.hunk.nstart) or 1
  if valid_tab(st.origin_tab) then
    api.nvim_set_current_tabpage(st.origin_tab)
  else
    vim.cmd("tabnew")
    st.origin_tab = api.nvim_get_current_tabpage()
  end
  vim.cmd.edit(vim.fn.fnameescape(st.root .. "/" .. f.path))
  local last = api.nvim_buf_line_count(0)
  api.nvim_win_set_cursor(0, { math.max(1, math.min(target, last)), 0 })
  vim.cmd("normal! zz")
end

function A.refresh(st)
  reload(st, { force = true })
end

function A.close()
  M.close()
end

local keys = {
  { "x", "toggle_viewed", "mark the file viewed (collapses it)" },
  { "<Tab>", "toggle_fold", "fold / unfold the file" },
  { "za", "toggle_fold" },
  { "]f", "next_file", "next file" },
  { "[f", "prev_file", "previous file" },
  { "]h", "next_hunk", "next hunk" },
  { "[h", "prev_hunk", "previous hunk" },
  { "e", "expand", "show 20 more lines of context (on a @@ row)" },
  { "E", "expand_all", "show all hidden lines there" },
  { "s", "toggle_view", "split / unified" },
  { "b", "pick_base", "compare against another branch" },
  { "<CR>", "enter", "open the real file at this line" },
  { "t", "toggle_sidebar", "show / hide the file tree" },
  { "f", "pick_file", "jump to a changed file" },
  { "R", "refresh", "reload the diff" },
  { "q", "close", "close the review" },
  { "g?", "help", "this help" },
}

function A.help()
  local lines = { " Review keys", "" }
  for _, k in ipairs(keys) do
    if k[3] then
      lines[#lines + 1] = (" %-6s %s "):format(k[1], k[3])
    end
  end
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = #lines,
    row = math.floor((vim.o.lines - #lines) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
  for _, key in ipairs({ "q", "<Esc>", "g?" }) do
    vim.keymap.set("n", key, function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })
  end
end

set_keys = function(st, buf)
  for _, k in ipairs(keys) do
    vim.keymap.set("n", k[1], function()
      if S.cur == st then
        A[k[2]](st)
      end
    end, { buffer = buf, nowait = true, silent = true, desc = "Review: " .. (k[3] or k[2]) })
  end
end

-- Setup ------------------------------------------------------------------------

function M.setup(opts)
  S.config = vim.tbl_extend("force", S.config, opts or {})
  local group = api.nvim_create_augroup("review", { clear = true })

  api.nvim_create_user_command("Review", function(cmd)
    M.open(cmd.args)
  end, {
    nargs = "?",
    desc = "Review the working tree against a branch, GitHub style",
    complete = function(lead)
      return vim.tbl_filter(function(name)
        return name:find(lead, 1, true) == 1
      end, git.branches_sync(vim.fn.getcwd()))
    end,
  })

  api.nvim_create_autocmd("ColorScheme", { group = group, callback = hl.setup })

  -- Coming back to the review tab picks up edits made elsewhere.
  api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      local st = S.cur
      if st and api.nvim_get_current_tabpage() == st.tab then
        reload(st)
      end
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local st, win = S.cur, tonumber(ev.match)
      if not st then
        return
      end
      if win == st.win then
        vim.schedule(M.close)
      elseif win == st.swin then
        st.swin = nil
      elseif win == st.rwin then
        -- the right half was closed by hand: fall back to unified
        st.rwin = nil
        vim.schedule(function()
          if S.cur == st and st.view == "split" and valid_win(st.win) then
            st.view = "unified"
            st.side_of = { [st.buf] = "unified" }
            page_opts(st.win, false)
            redraw(st)
          end
        end)
      end
    end,
  })
end

return M
