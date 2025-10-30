-- vim remaps
vim.g.mapleader = " "
vim.keymap.set("n", "-", "<CMD>Oil<CR>", {})
vim.keymap.set("n", "<leader>h", ":vs<CR>", {})
vim.keymap.set("n", "<leader>v", ":sv<CR>", {})
vim.keymap.set({"n", "v"}, "J", "3j")
vim.keymap.set({"n", "v"}, "K", "3k")

vim.opt.clipboard = "unnamedplus"
vim.keymap.set({"n", "v"}, "<leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set("n", "<leader>Y", '"+Y', { noremap = true, silent = true })
vim.keymap.set({"n", "v"}, "<leader>p", '"+p', { noremap = true, silent = true })
vim.keymap.set({"n", "v"}, "<leader>P", '"+P', { noremap = true, silent = true })

-- Copy relative file path
vim.keymap.set("n", "<leader>cp", function()
  local path = vim.fn.expand('%')
  if path == '' then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', path)
  vim.notify("Copied to clipboard: " .. path)
end, { noremap = true, silent = true, desc = "Copy relative file path" })
