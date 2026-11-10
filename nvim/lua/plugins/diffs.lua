-- Read by the plugin when it loads; there is no setup() call.
vim.g.diffs = {
  integrations = { "neogit", "gitsigns" },
}

-- Same keys git-conflict.nvim used, set only in buffers that have conflicts.
vim.api.nvim_create_autocmd("User", {
  pattern = "DiffsConflictDetected",
  callback = function(event)
    local opts = { buffer = event.data.bufnr }
    vim.keymap.set("n", "co", "<Plug>(diffs-conflict-ours)", opts)
    vim.keymap.set("n", "ct", "<Plug>(diffs-conflict-theirs)", opts)
    vim.keymap.set("n", "cb", "<Plug>(diffs-conflict-both)", opts)
    vim.keymap.set("n", "c0", "<Plug>(diffs-conflict-none)", opts)
    vim.keymap.set("n", "]x", "<Plug>(diffs-conflict-next)", opts)
    vim.keymap.set("n", "[x", "<Plug>(diffs-conflict-prev)", opts)
  end,
})
