-- Everything that talks to git. Read-only: no fetch, no index writes.
-- Functions marked (async) must run inside async.run.
local async = require("review.async")
local diff = require("review.diff")
local S = require("review.state")

local M = {}

local function cmd(args)
  local full = { "git", "-c", "core.quotepath=off" }
  return vim.list_extend(full, args)
end

--- (async) stdout on success, or nil + stderr.
function M.exec(root, args)
  local res = async.system(cmd(args), { cwd = root })
  if res.code ~= 0 then
    return nil, res.stderr
  end
  return res.stdout
end

local function trim(s)
  return s and (s:gsub("%s+$", "")) or nil
end

local function lines_of(out)
  local list = {}
  for line in (out or ""):gmatch("[^\n]+") do
    list[#list + 1] = line
  end
  return list
end

--- (async) repository root for a directory, or nil.
function M.root(dir)
  local out = M.exec(dir, { "rev-parse", "--show-toplevel" })
  return trim(out)
end

--- (async) Prefer origin/<name> over the local branch; nil when neither exists.
function M.resolve(root, name)
  local candidates = { { "refs/remotes/origin/" .. name, "origin/" .. name }, { "refs/heads/" .. name, name }, { name, name } }
  for _, c in ipairs(candidates) do
    if M.exec(root, { "rev-parse", "--verify", "--quiet", c[1] .. "^{commit}" }) then
      return c[2]
    end
  end
  return nil
end

local function branch_names(out)
  local seen, list = {}, {}
  for _, ref in ipairs(lines_of(out)) do
    local name = ref:gsub("^origin/", "")
    if name ~= "HEAD" and name ~= "origin" and not seen[name] then
      seen[name] = true
      list[#list + 1] = name
    end
  end
  return list
end

local branch_args = { "for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes/origin" }

--- (async)
function M.branches(root)
  return branch_names(M.exec(root, branch_args))
end

--- Blocking variant, for command-line completion.
function M.branches_sync(dir)
  local res = vim.system(cmd(branch_args), { cwd = dir }):wait()
  return res.code == 0 and branch_names(res.stdout) or {}
end

--- Text of a file, or nil when missing, too large or binary.
function M.read(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" or stat.size > S.config.max_file_bytes then
    return nil
  end
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local text = fd:read("*a")
  fd:close()
  if not text or text:find("\0", 1, true) then
    return nil
  end
  return text
end

function M.split_lines(text)
  local lines = vim.split(text, "\n", { plain = true })
  if lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines
end

--- (async) Everything needed to draw a review of `ref` against the working tree.
function M.load(root, ref)
  local head, err = M.exec(root, { "rev-parse", "--abbrev-ref", "HEAD" })
  if not head then
    return nil, "no commits yet: " .. (trim(err) or "")
  end
  local branch = trim(head)
  if branch == "HEAD" then
    branch = trim(M.exec(root, { "rev-parse", "--short", "HEAD" })) or "HEAD"
  end
  -- The point the branch split off; unrelated histories fall back to the ref.
  local merge_base = trim(M.exec(root, { "merge-base", ref, "HEAD" })) or ref

  local out, derr = M.exec(root, {
    "diff",
    "--no-color",
    "--no-ext-diff",
    "-M",
    "--src-prefix=a/",
    "--dst-prefix=b/",
    merge_base,
  })
  if not out then
    return nil, trim(derr)
  end
  local files = diff.parse(out)

  for _, f in ipairs(files) do
    if f.status ~= "D" and not f.binary then
      local text = M.read(root .. "/" .. f.path)
      if text then
        f.new_text, f.new_lines = text, M.split_lines(text)
      end
    end
  end

  local untracked = lines_of(M.exec(root, { "ls-files", "--others", "--exclude-standard" }))
  for i, path in ipairs(untracked) do
    if i % 100 == 0 then
      async.yield() -- many untracked files: let the editor breathe
    end
    if path:sub(-1) ~= "/" then
      local text = M.read(root .. "/" .. path)
      files[#files + 1] = diff.untracked(path, text, text and M.split_lines(text))
    end
  end

  return { branch = branch, merge_base = merge_base, files = files }
end

return M
