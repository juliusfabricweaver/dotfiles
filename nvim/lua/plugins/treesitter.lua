-- nvim-treesitter `main` branch: it only installs parsers and queries.
-- Highlighting and indent are switched on per buffer below.
local ts = require("nvim-treesitter")

ts.install({
  "bash", "blade", "c", "cpp", "css", "csv", "diff", "dockerfile", "editorconfig",
  "git_config", "gitattributes", "gitcommit", "gitignore", "groovy", "html", "ini",
  "java", "javascript", "json", "kotlin", "lua", "make", "markdown",
  "markdown_inline", "matlab", "mermaid", "pem", "php", "properties", "python",
  "query", "requirements", "ruby", "sql", "swift", "toml", "tsx",
  "typescript", "vim", "vimdoc", "vue", "xml", "yaml",
})

local function start(buf, lang)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  if not pcall(vim.treesitter.start, buf, lang) then
    return false
  end
  if vim.treesitter.query.get(lang, "indents") then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
  return true
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
  callback = function(ev)
    local lang = vim.treesitter.language.get_lang(ev.match)
    if not lang or start(ev.buf, lang) then
      return
    end
    -- replaces the old `auto_install = true`
    if vim.list_contains(ts.get_available(), lang) then
      ts.install(lang):await(function()
        vim.schedule(function()
          start(ev.buf, lang)
        end)
      end)
    end
  end,
})
