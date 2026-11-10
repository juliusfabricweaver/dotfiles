# Review: a GitHub-style diff viewer for Neovim

Date: 2026-11-10
Status: draft, awaiting approval

Items marked **(call)** were decided by the author of this document, not by
Julien. Everything else is something Julien said or approved.

## Intent

Julien wants to review a branch locally in Neovim the way a pull request is
reviewed on GitHub's "Files changed" page: every changed file stacked on one
scrolling page, a file tree beside it, and a "Viewed" tick that collapses a file
once it has been read. Neovim's built-in diff mode and diffview show one file at
a time in two windows, which is the thing this replaces for review.

The approved mockup is the reference for layout. A copy is at the end of this
document as a text sketch.

## Goals

1. One scrolling page containing all changed files, each with a header bar and
   its hunks, laid out like GitHub's "Files changed".
2. Marking a file as viewed collapses it to its header bar.
3. Compares against `develop` by default, including uncommitted changes, with
   the ability to choose another branch.
4. Unified view by default with a toggle to split view (old left, new right).
5. Colours come from the active colourscheme (gruvbox today), not GitHub's
   palette.
6. Lives in Julien's Neovim config as local Lua; no new plugins.

## Non-goals (for now)

- Loading real GitHub pull requests, review comments, approving.
- Choosing a commit, a commit range, or "uncommitted only" as the comparison.
- Staging, reverting or editing from inside the viewer. It is read-only.
- Sticky file headers while scrolling. **(call)**
- Conflict/merge-in-progress states, submodule contents. **(call)**

PR loading is a likely follow-up. Keep "where the list of file diffs comes
from" separate from "how a list of file diffs is drawn" so a second source can
be added later without touching rendering.

## Anti-goals

- Looking like a foreign app inside gruvbox (hardcoded GitHub hex colours).
- Changing anything in git: no index writes, no fetch, no checkout.
- Writing state files into the dotfiles repo.
- Breaking or reconfiguring diffview, diffs.nvim, gitsigns or neogit. They stay.
- A noticeable pause when opening a normal-sized branch.

## Environment and constraints

- Neovim 0.12.6, plugins via built-in `vim.pack`. Config root:
  `~/.config/nvim`, tracked in the `~/.config` dotfiles repo.
- Config convention: one file per plugin in `lua/plugins/`, loaded by name from
  the list in `init.lua`. Leader is space.
- Already installed and usable: nvim-treesitter (main branch), fzf-lua,
  nvim-web-devicons, gruvbox.nvim (with `inverse = true`, so the stock
  `DiffAdd`/`DiffDelete` groups are reverse-video and cannot be used as row
  backgrounds directly).
- Taken keys: `<leader>gs`, `gc`, `gh` (diffview), `<leader>gd`, `gi` (LSP),
  `<leader>G*` (gitsigns), `]h`/`[h` (gitsigns hunks, buffer-local to real
  files).
- No unit tests: Julien's standing instruction is not to write tests as part of
  feature work. Verify by running it (see "Verification").

## Where it lives **(call)**

- `lua/review/` holds the viewer, split into modules as the builder sees fit.
  A sensible split: git access, diff parsing, page model/state, rendering,
  highlights, sidebar tree, persistence.
- `lua/plugins/review.lua` calls `require("review").setup({...})` and sets the
  global key. Add `"review"` to the load list in `init.lua` after `fzf-lua`.

## Opening it **(call)**

- `:Review` opens against the default base. `:Review <branch>` opens against
  that branch, with branch-name completion.
- `<leader>gr` runs `:Review`.
- It opens in its own tab. Only one review tab exists at a time; running
  `:Review` again focuses it and reloads.
- Outside a git repo: an error notification, nothing opens.
- No changes: a "No changes against <base>" notification, nothing opens.

## What is compared

- Julien's words: default against `develop`, uncommitted changes included, and
  the only other choice needed is another branch.
- Precisely **(call)**: the diff is from the merge-base of the base branch and
  `HEAD` to the working tree. That is what the PR would contain if everything
  were committed now. Staged and unstaged changes are both included. Untracked,
  non-ignored files appear as added files.
- Resolving a branch name **(call)**: prefer `origin/<name>` when it exists,
  otherwise the local branch. Reason: a stale local `develop` would otherwise
  pull other people's commits into the diff after a rebase. Never fetch.
- Default base **(call)**: `default_base = "develop"` in setup options. If
  neither `origin/develop` nor `develop` exists, fall back to `main`, then
  `master`, and say so in a notification. (The dotfiles repo itself only has
  `main`.)
- Rename detection on. A renamed file's header reads `old/path → new/path`.
- Binary files show a header and a single "Binary file not shown" row.

## The page

One read-only scratch buffer (not modifiable, no file, no swap), `nowrap`
**(call)**, in the main window of the tab.

Julien's config sets `scrolloff = 90`, which keeps the cursor centred. The
review windows override it locally so that jumping to a file (sidebar Enter,
`]f`/`[f`, the move after marking viewed) puts that file's header at the top of
the window, as on GitHub **(call)**.

**Top bar** (the window's winbar): `base ← branch`, number of files changed,
total `+n −n`, and `x / y viewed`.

**Per file, in git's path order:**

- A header bar: fold marker (`▾`/`▸`), path, `+n −n`, a five-block
  added/removed ratio bar, and `☐ Viewed` / `☑ Viewed` at the right. A viewed
  header is dimmed.
- Then, when expanded, its hunks. Each hunk starts with a hunk row showing the
  `@@ -a,b +c,d @@ context` text on a blue-tinted background.
- Diff rows carry: old line number, new line number, a `+`/`-`/blank sign, and
  the code. Added rows have a green-tinted background, removed rows red-tinted,
  with a stronger tint on the line-number cells.
- Within a changed block, removed and added lines are paired in order and the
  parts that actually differ get a stronger tint (word-level highlight). Skip
  this when a pair is too dissimilar for it to help; threshold is the builder's
  call.
- Code is syntax-highlighted by treesitter under the tints. Highlights are
  computed by parsing the full old and full new file contents and mapping
  captures onto the rows, so a hunk that starts mid-function or mid-string is
  still coloured correctly. No parser for the filetype means plain text.
- Line numbers and signs must not be part of the buffer text, so yanking gives
  clean code. How (statuscolumn, inline virtual text) is the builder's call.

**Collapsed by default (call):** deleted files, and files with more than 1000
changed lines (header notes "Large diff"). They expand like any other file.

**Expanding hidden context:** with the cursor on a hunk row, one key reveals 20
more lines of the unchanged gap above that hunk and another reveals the whole
gap. When unchanged lines remain after a file's last hunk, a trailing expander
row does the same for the end of the file. When a gap is fully revealed the
hunk row disappears and the two hunks read as one.

## Viewed and collapsing

- Toggling viewed on a file (cursor anywhere in it) ticks its box, collapses it
  to the header, and moves the cursor to the next file's header **(call)**.
  Toggling again unticks and expands.
- Folding without marking viewed is a separate key.
- The top bar count updates immediately. The sidebar shows `✓` on viewed files.
- Persistence **(call)**: saved under `stdpath("state")/review/`, keyed by repo
  root, current branch and base. For each viewed file store a hash of that
  file's diff text. On load, a file counts as viewed only if the hash still
  matches; otherwise it comes back unticked and expanded. This is GitHub's
  "changed since you viewed it" behaviour.

## Sidebar

A narrow window on the left (about 35 columns) with a tree of the changed files:

- Directories with a single child are compressed into one row (`nvim/lua`).
- Each file row: devicon when available, name, status letter (`M`, `A`, `D`,
  `R`) coloured to match, and `✓` when viewed.
- Enter on a file scrolls the page to that file's header. It does not change
  the file's collapsed state **(call)**.
- The row for the file under the page cursor is highlighted as the cursor moves.
- A key toggles the sidebar.
- Instead of GitHub's live filter box, a key opens an fzf-lua picker over the
  changed files and jumps to the chosen one **(call)**.

## Split view

Toggled with one key; the choice is remembered for the session, unified on
start. Old on the left, new on the right, rows aligned, with blank filler rows
where one side has no counterpart, as in the mockup. Each side shows its own
line number. The two sides scroll together. File headers and hunk rows must
still read as full-width bars. Whether this is two scroll-bound windows or
something else is the builder's call; the sidebar stays to the left of both.

## Colours

- All highlight groups are the viewer's own (`Review*`), defined with
  `default = true` so they can be overridden, and rebuilt on `ColorScheme`.
- Tints are derived, not hardcoded **(call)**: take the foreground of the
  scheme's added/removed/blue colours (`Added`, `Removed`, falling back to
  gruvbox's green/red/blue groups) and blend it into the `Normal` background:
  roughly 15% for a row, 30% for a line-number cell, 40% for a word-level
  highlight. Hunk rows use the blue the same way. Tune by eye in gruvbox dark;
  it should also be acceptable in gruvbox light.
- Header bars use a background slightly lifted from `Normal`.
- Syntax highlight must stay readable on top of the tints, and word-level
  tints must win over row tints.

## Keys inside the viewer **(call)**

Buffer-local, shown in a `g?` help float. The buffer is read-only, so editing
keys are free to reuse. Visual mode and yanking stay untouched.

| Key | Action |
|-----|--------|
| `x` | toggle viewed for the file under the cursor |
| `<Tab>` / `za` | fold or unfold the file |
| `]f` / `[f` | next / previous file |
| `]h` / `[h` | next / previous hunk |
| `e` / `E` | expand 20 lines / the whole gap at a hunk row |
| `s` | toggle split and unified |
| `b` | pick another base branch (fzf-lua), reload |
| `<CR>` | open the real file at that line |
| `t` | toggle the sidebar |
| `f` | fzf-lua over changed files |
| `R` | refresh |
| `q` | close the review tab |

`<CR>` opens the working-tree file in the tab Julien came from (a new tab if
that one is gone). On a removed row it goes to the nearest surviving line; on a
deleted file it does nothing but say so.

## Refreshing **(call)**

`R` reloads. The page also reloads when the review tab is re-entered, so edits
made elsewhere show up. A reload keeps the cursor on the same file and line
where possible, keeps fold state, and re-validates viewed marks.

## Performance

Git calls are asynchronous. Opening a branch with around 100 files and 5,000
changed lines should feel immediate. Treesitter highlighting may be computed
per file when that file is first expanded or scrolled into view, rather than
all up front. How is the builder's call.

## Left to the builder

Module boundaries, the buffer/extmark/statuscolumn mechanics, how collapsing is
implemented (re-render from state or native folds), the split-view window
mechanics, the word-diff algorithm and threshold, exact blend percentages, and
the storage file format.

## Verification

No test suite. Check by running against real repositories:

- a work repo with a `develop` branch and a feature branch that has committed,
  staged, unstaged and untracked changes, a rename, a deletion and a binary;
- the dotfiles repo (no `develop`, on `main`) for the fallback path;
- a non-git directory and a clean branch for the two "nothing opens" paths.

Confirm against the mockup: layout, viewed-collapses, count in the top bar,
viewed state surviving a restart and resetting when the file changes, branch
picker, split toggle, context expansion, yank gives clean text.

## Reference sketch (unified)

```
 ▾ nvim/lua         │ develop ← feature/x   5 files changed +48 −21   1 / 5 viewed
   ▾ plugins        │
     ✓ git.lua    M │ ▸ nvim/lua/plugins/git.lua  +6 −2                  ☑ Viewed
       review.lua M │ ▾ nvim/lua/plugins/review.lua  +5 −3  ■■■■■        ☐ Viewed
       status.lua A │     ↕      @@ -12,9 +12,11 @@ local function open(base)
     options.lua  M │    12 12    local function open(base)
 ▾ spicetify        │    13    -    base = base or "main"
     old.ini      D │       13 +    base = base or config.default_base
                    │    14 14      local files = git.changed_files(base)
                    │
                    │ ▸ nvim/lua/plugins/statusline.lua  +31 −0          ☐ Viewed
```

## Reference sketch (split, one file)

The approved mockup showed split view like this: one full-width header, old on
the left with its own line numbers, new on the right, blank filler rows where
a side has no counterpart.

```
 ▾ nvim/lua/plugins/review.lua  +5 −3                                   ☐ Viewed
 12   local function open(base)          │ 12   local function open(base)
 13 -   base = base or "main"            │ 13 +   base = base or config.default_base
 14     local files = git.changed(base)  │ 14     local files = git.changed(base)
 15 -   if #files == 0 then return end   │ 15 +   if #files == 0 then
                                         │ 16 +     vim.notify("No changes")
                                         │ 17 +     return
                                         │ 18 +   end
 16     local page = render.page(files)  │ 19     local page = render.page(files)
```
