-- Builds the sidebar tree and the page order (the two always match).
local M = {}

--- Returns entries = { { depth, name, file? } } and the files in tree order.
function M.build(files)
  local root = { dirs = {}, files = {} }
  for _, f in ipairs(files) do
    local parts = vim.split(f.path, "/", { plain = true })
    local node = root
    for i = 1, #parts - 1 do
      local d = node.dirs[parts[i]]
      if not d then
        d = { name = parts[i], dirs = {}, files = {} }
        node.dirs[parts[i]] = d
      end
      node = d
    end
    node.files[#node.files + 1] = { name = parts[#parts], file = f }
  end

  local entries, ordered = {}, {}
  local function by_name(a, b)
    return a.name < b.name
  end
  local function walk(node, depth)
    local dirs = vim.tbl_values(node.dirs)
    table.sort(dirs, by_name)
    for _, d in ipairs(dirs) do
      local name = d.name
      -- a/b/c with nothing else on the way becomes one row
      while #d.files == 0 and vim.tbl_count(d.dirs) == 1 do
        local _, child = next(d.dirs)
        name, d = name .. "/" .. child.name, child
      end
      entries[#entries + 1] = { depth = depth, name = name }
      walk(d, depth + 1)
    end
    table.sort(node.files, by_name)
    for _, e in ipairs(node.files) do
      entries[#entries + 1] = { depth = depth, name = e.name, file = e.file }
      ordered[#ordered + 1] = e.file
    end
  end
  walk(root, 0)
  return entries, ordered
end

return M
