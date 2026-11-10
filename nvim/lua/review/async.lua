-- Tiny coroutine helpers so git calls read top-to-bottom without blocking.
local M = {}

local function resume(co, ...)
  local ok, err = coroutine.resume(co, ...)
  if not ok then
    vim.notify("review: " .. debug.traceback(co, tostring(err)), vim.log.levels.ERROR)
  end
end

function M.run(fn)
  resume(coroutine.create(fn))
end

--- Run a command; must be called inside M.run. Returns the vim.system result.
function M.system(cmd, opts)
  local co = coroutine.running()
  vim.system(cmd, opts or {}, function(res)
    vim.schedule(function()
      resume(co, res)
    end)
  end)
  return coroutine.yield()
end

--- Give the editor a chance to redraw and handle input.
function M.yield()
  local co = coroutine.running()
  vim.schedule(function()
    resume(co)
  end)
  coroutine.yield()
end

return M
