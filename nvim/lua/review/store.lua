-- Viewed marks, kept outside the config: stdpath("state")/review/<repo>.json
-- Shape: { ["<branch> <- <base>"] = { ["path"] = "<hash of that file's diff>" } }
local M = {}

local function file(root)
  return vim.fs.joinpath(vim.fn.stdpath("state"), "review", vim.fn.sha256(root):sub(1, 16) .. ".json")
end

function M.read(root)
  local fd = io.open(file(root), "r")
  if not fd then
    return {}
  end
  local text = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, text)
  return (ok and type(data) == "table") and data or {}
end

function M.write(root, key, map)
  local all = M.read(root)
  all[key] = next(map) and map or nil
  local path = file(root)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = io.open(path, "w")
  if not fd then
    return
  end
  fd:write(next(all) and vim.json.encode(all) or "{}")
  fd:close()
end

return M
