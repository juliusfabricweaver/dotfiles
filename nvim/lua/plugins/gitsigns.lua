return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "│" },
      change = { text = "│" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
    },
    current_line_blame = true,
    current_line_blame_opts = {
      delay = 500,
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map("n", "]h", gs.next_hunk, { desc = "Next hunk" })
      map("n", "[h", gs.prev_hunk, { desc = "Prev hunk" })

      -- Actions (using <leader>g for git)
      map("n", "<leader>Gs", gs.stage_hunk, { desc = "Stage hunk" })
      map("n", "<leader>Gr", gs.reset_hunk, { desc = "Reset hunk" })
      map("n", "<leader>Gu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
      map("n", "<leader>Gp", gs.preview_hunk, { desc = "Preview hunk" })
      map("n", "<leader>Gb", function() gs.blame_line({ full = true }) end, { desc = "Blame line" })
      map("n", "<leader>Gd", gs.diffthis, { desc = "Diff this" })
    end,
  },
}
