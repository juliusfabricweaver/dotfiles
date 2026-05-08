vim.opt.signcolumn = 'yes'

-- blink.cmp provides capabilities automatically
local capabilities = require('blink.cmp').get_lsp_capabilities()

vim.api.nvim_create_autocmd('LspAttach', {
  desc = 'LSP actions',
  callback = function(event)
    local opts = { buffer = event.buf }

    vim.keymap.set('n', '<leader>d', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
    vim.keymap.set('n', '<leader>gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    vim.keymap.set('n', '<leader>gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
    vim.keymap.set('n', '<leader>rf', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
    vim.keymap.set('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
    vim.keymap.set({ 'n', 'x' }, '<leader>f', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
    vim.keymap.set('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
  end,
})

require('mason').setup({})

-- Default capabilities applied to every server.
vim.lsp.config('*', { capabilities = capabilities })

local intelephense_cache = vim.fn.stdpath('cache') .. '/intelephense'

vim.lsp.config('intelephense', {
  init_options = {
    globalStoragePath = intelephense_cache,
    storagePath = intelephense_cache,
  },
  settings = {
    intelephense = {
      globalStoragePath = intelephense_cache,
      storagePath = intelephense_cache,
      stubs = {
        "bcmath", "bz2", "calendar", "Core", "curl", "date", "dba", "dom", "enchant",
        "fileinfo", "filter", "ftp", "gd", "gettext", "hash", "iconv", "imap", "intl",
        "json", "ldap", "libxml", "mbstring", "mcrypt", "mysql", "mysqli", "password",
        "pcntl", "pcre", "PDO", "pdo_mysql", "Phar", "readline", "recode", "Reflection",
        "regex", "session", "SimpleXML", "soap", "sockets", "sodium", "SPL", "standard",
        "superglobals", "sysvsem", "sysvshm", "tokenizer", "xml", "xdebug", "xmlreader",
        "xmlwriter", "yaml", "zip", "zlib", "wordpress", "phpunit",
      },
    },
  },
})

vim.lsp.config('markdown_oxide', {
  capabilities = vim.tbl_deep_extend('force', capabilities, {
    workspace = {
      didChangeWatchedFiles = { dynamicRegistration = true },
    },
  }),
})

local mason_registry = require('mason-registry')
if mason_registry.is_installed('vue-language-server') then
  local vue_typescript_plugin = vim.fn.expand('$MASON/packages/vue-language-server')
      .. '/node_modules/@vue/language-server'
      .. '/node_modules/@vue/typescript-plugin'

  vim.lsp.config('ts_ls', {
    init_options = {
      plugins = {
        {
          name = '@vue/typescript-plugin',
          location = vue_typescript_plugin,
          languages = { 'javascript', 'typescript', 'vue' },
        },
      },
    },
    filetypes = {
      'javascript', 'javascriptreact', 'javascript.jsx',
      'typescript', 'typescriptreact', 'typescript.tsx',
      'vue', 'json',
    },
  })
end

require('mason-lspconfig').setup({
  ensure_installed = { 'lua_ls', 'ts_ls', 'markdown_oxide', 'intelephense' },
})
