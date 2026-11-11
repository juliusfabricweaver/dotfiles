# Review

A diff viewer for Neovim laid out like GitHub's pull request "Files changed"
page: every changed file stacked on one scrolling page, a file tree beside it,
and a "Viewed" tick that collapses a file once you have read it.

It is a local plugin that lives in this config (`lua/review/`). It needs
Neovim 0.12 and git. It uses fzf-lua, nvim-treesitter and nvim-web-devicons
when they are installed and works without them.

```
 Files changed       │ develop ← feature/x    5 files changed  +48 −21        1 / 5 viewed
 ▾ nvim/lua          │ ▸         nvim/lua/plugins/git.lua   +6 −2  ■■■■■         ☑ Viewed
   ▾ plugins         │
     ✓ git.lua     M │ ▾         nvim/lua/plugins/review.lua   +5 −3  ■■■■■      ☐ Viewed
       review.lua  M │    ↕      @@ -12,9 +12,11 @@ local function open(base)
       status.lua  A │  12  12   local function open(base)
     options.lua   M │  13     -   base = base or "main"
 ▾ spicetify         │      13 +   base = base or config.default_base
     old.ini       D │  14  14     local files = git.changed_files(base)
```

## Opening it

| How | What it does |
|-----|--------------|
| `<leader>gr` | Review the current branch against `develop` |
| `:Review` | Same |
| `:Review <branch>` | Review against another branch (Tab completes branch names) |

The review opens in its own tab. Only one review is open at a time: running
`:Review` again goes back to it, and `:Review <branch>` switches what it is
compared against.

The repository is the one containing the file you are in, or the current
directory if that file is not in a repository.

Nothing opens when you are not in a git repository (you get an error) or when
there are no changes (you get a "No changes against …" message).

## What is compared

The page shows what a pull request from your branch would contain if you
committed everything right now:

- from the point where your branch split off the base branch
- to the files on disk, so committed, staged and unstaged changes are all
  included
- plus untracked files that are not git-ignored, shown as added files

**Which branch.** A branch name means `origin/<name>` when that exists and the
local branch otherwise. The remote one is preferred because a stale local
`develop` would drag other people's commits into the diff after a rebase. The
top bar always shows which one was used. The viewer never fetches, so run
`git fetch` yourself if you want the latest remote state.

**Default branch.** `develop`. In a repository with no `develop`, it falls back
to `main`, then `master`, and tells you it did.

## Reading the page

**Top bar.** Base branch ← your branch, number of files changed, total lines
added and removed, and how many files you have marked viewed.

**File header.** For each file: a fold marker (`▾` open, `▸` collapsed), the
path, lines added and removed, a five-block bar showing the added/removed
ratio, and the Viewed box. A renamed file reads `old/path → new/path`.

**Hunk row.** The `@@ -12,9 +12,11 @@` row starts each block of changes.
Unchanged lines between hunks are hidden; `e` shows them for the whole file.

**Diff rows.** Two line-number columns (old file, new file), then `+` or `-`,
then the code. Added rows are tinted green, removed rows red. When a removed
line and an added line are versions of the same line, the words that actually
changed get a stronger tint. Code keeps its syntax colours.

**File tree.** Folders first, then files. Each file shows its status and a `✓`
once viewed. The file your cursor is in on the page is highlighted in the tree.

| Status | Meaning |
|--------|---------|
| `M` | modified |
| `A` | added (including untracked files) |
| `D` | deleted |
| `R` | renamed |

**Files that start collapsed.** Deleted files, files with more than 1000
changed lines (marked "large diff"), and files you already marked viewed.
Unfold them like any other file.

**Binary files** show a header and "Binary file not shown".

## Keys

These work inside the review. `g?` shows this list in a popup.

### Moving around

| Key | Action |
|-----|--------|
| `]f` / `[f` | Next / previous file |
| `]h` / `[h` | Next / previous hunk |
| `f` | Fuzzy-pick a changed file and jump to it |
| `Enter` in the file tree | Jump to that file on the page |
| `Enter` on the page | Open the real file at that line |

`Enter` on the page opens the file in the tab you came from. On a removed line
it goes to the nearest line that still exists. A deleted file has nothing to
open.

### Reviewing

| Key | Action |
|-----|--------|
| `x` | Mark the file viewed, or unmark it |
| `Tab` or `za` | Fold or unfold the hunk you are in; on a file header, the whole file |

A folded hunk shrinks to its `@@` row, which shows `▸` and how many lines it is
hiding. `Tab` on that row opens it again. Folded hunks are not remembered
between sessions.

Both keys also work in the file tree. On a file they act on that file. On a folder
they act on every file inside it, subfolders included: if all of them are
already viewed (or folded), they are all unmarked (or unfolded); otherwise they
are all marked (or folded).

### Changing the view

| Key | Action |
|-----|--------|
| `s` | Switch between unified and side-by-side |
| `e` | Show all hidden lines of the file, or hide them again |
| `b` | Pick another branch to compare against |
| `t` | Hide or show the file tree |
| `R` | Reload |
| `q` | Close the review |
| `g?` | Show the key list |

`e` is a toggle for the file your cursor is in. It shows every unchanged line
git left out, so you see the whole file with the changes in place and no `@@`
rows in between. Press `e` again anywhere in the file to hide them all again.
Other files are not affected.

Showing hidden lines and folding hunks do not affect each other. A folded hunk
stays folded when the lines above it are shown, and keeps its `@@` row so you
can open it. Folding a hunk never hides lines that `e` revealed.

### Ordinary Vim keys

Search, visual mode and yanking work as usual. Line numbers and `+`/`-` signs
are not part of the text, so yanking gives you clean code.

The review is read-only. Because of that, `x`, `e`, `b`, `f`, `t` and `s` do
the things listed above here and not their usual Vim motions or edits.

## Viewed files

Pressing `x` ticks the file's Viewed box, collapses it to its header, and moves
you to the next file, which slides up underneath. The count in the top bar and
the `✓` in the tree update straight away.

Viewed marks are remembered between sessions, separately for each repository,
branch and base branch.

If a file changes after you marked it, its mark is dropped the next time the
review loads and the file opens again. A mark means "I have seen exactly this
diff".

Marks are stored outside this config, in
`~/.local/state/nvim/review/<repository-id>.json`. Deleting that file forgets
all marks for that repository.

## Side-by-side view

`s` splits the page in two: the old file on the left, the new file on the
right, each with its own line numbers. Rows are aligned, with blank filler
where one side has nothing to show. The two halves scroll and move together.
`s` again returns to unified. The view always starts unified.

## Staying up to date

The review reloads whenever you come back to its tab, so after you press
`Enter`, edit the file and return, the page shows your edit. `R` reloads on
demand. A reload keeps your cursor position, your folds and the context you
revealed in files that did not change.

## Configuration

Setup is in `lua/plugins/review.lua`. These are the options and their defaults:

```lua
require("review").setup({
  default_base = "develop",             -- branch :Review compares against
  fallback_bases = { "main", "master" },-- tried when default_base is missing
  sidebar_width = 36,                   -- columns for the file tree
  large_diff = 1000,                    -- changed lines above which a file starts collapsed
  max_file_bytes = 1024 * 1024,         -- larger files get no context expansion or syntax colours
})
```

The `<leader>gr` mapping is set in the same file.

## Colours

Colours are taken from the active colourscheme, not hardcoded, and are rebuilt
when the colourscheme changes. The green, red and blue come from gruvbox's
`GruvboxGreen`, `GruvboxRed` and `GruvboxBlue` (or `Added`, `Removed` and
`Function` in other schemes) and are blended into the normal background.

To change one, define the group after the colourscheme loads. The main ones:

| Group | Used for |
|-------|----------|
| `ReviewAdd` / `ReviewDel` | Added / removed row background |
| `ReviewAddWord` / `ReviewDelWord` | Changed words within a row |
| `ReviewAddLnum` / `ReviewDelLnum` | Line-number cells of changed rows |
| `ReviewAddSign` / `ReviewDelSign` | The `+` / `-` signs |
| `ReviewLnum` | Line numbers of unchanged rows |
| `ReviewHunk` / `ReviewHunkLnum` | The `@@` row and its gutter |
| `ReviewFileHeader` | File header bar |
| `ReviewPath` / `ReviewPathViewed` | File path, normal and viewed |
| `ReviewViewedOn` / `ReviewViewedOff` | The Viewed box |
| `ReviewFiller` | Blank cells in side-by-side view |
| `ReviewTreeCurrent` | Current file in the tree |
| `ReviewStatusM` / `A` / `D` / `R` | Status letters in the tree |

The full list is in `lua/review/hl.lua`.

## Limits

- **Read-only.** You cannot stage, unstage, revert or edit from the review.
- **Local only.** It does not load GitHub pull requests or review comments.
- **Branches only.** You cannot compare against a specific commit or a range.
- **No fetching.** `origin/<branch>` is only as fresh as your last fetch.
- **Unsaved buffers are ignored.** The page shows files as they are on disk.
- **Large files.** Files over 1 MB show their changes but offer no hidden
  context and no syntax colours.
- **Filtered files.** In files with git clean/smudge filters (the spicetify
  config here), revealed context and syntax colours can be slightly off,
  because git compares the filtered content while the viewer reads the file on
  disk.
- **Not handled:** merge conflicts in progress and submodule contents.

## How it is put together

| File | Role |
|------|------|
| `init.lua` | Commands, keys, windows, loading and reloading |
| `git.lua` | All git calls (read-only) |
| `diff.lua` | Parsing git's output, word-level diff, context expansion, building rows |
| `render.lua` | Drawing the page, gutter, top bar and file tree |
| `syntax.lua` | Treesitter colours for diff rows |
| `tree.lua` | File tree and page order |
| `hl.lua` | Highlight groups |
| `store.lua` | Saving viewed marks |
| `state.lua` | The open review and the configuration |
| `async.lua` | Helpers for running git without blocking |

**Large diffs.** The page can hold hundreds of thousands of rows. Colours are
not stored on the buffer: they are applied only to the rows on screen each time
Neovim draws, and syntax colours for a file are worked out the first time that
file scrolls into view. Folding, marking viewed and showing hidden lines redo
only the rows of the file concerned.

`git.lua` produces a list of file diffs and `render.lua` draws a list of file
diffs, so a second source, such as a real GitHub pull request, can be added
without touching the drawing code.

The original design notes are in
`docs/superpowers/specs/2026-11-10-review-diff-viewer-design.md`.
