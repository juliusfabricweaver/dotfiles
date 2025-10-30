vim.opt.signcolumn = 'yes'

local capabilities = require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
local lspconfig_defaults = require('lspconfig').util.default_config
lspconfig_defaults.capabilities = vim.tbl_deep_extend(
  'force',
  lspconfig_defaults.capabilities,
  require('cmp_nvim_lsp').default_capabilities()
)

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
require('mason-lspconfig').setup({
  ensure_installed = { "lua_ls", "ts_ls", "markdown_oxide", "intelephense" },
  handlers = {
    function()
      require("lspconfig").markdown_oxide.setup({
        capabilities = vim.tbl_deep_extend(
          'force',
          capabilities,
          {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = true,
              },
            },
          }
        ),
      })
    end,
    intelephense = function()
      require('lspconfig').intelephense.setup({
        capabilities = capabilities,
        settings = {
          intelephense = {
            storagePath = vim.fn.stdpath("cache") .. "/intelephense",
            stubs = {
              "bcmath", "bz2", "calendar", "Core", "curl", "date", "dba", "dom", "enchant",
              "fileinfo", "filter", "ftp", "gd", "gettext", "hash", "iconv", "imap", "intl",
              "json", "ldap", "libxml", "mbstring", "mcrypt", "mysql", "mysqli", "password",
              "pcntl", "pcre", "PDO", "pdo_mysql", "Phar", "readline", "recode", "Reflection",
              "regex", "session", "SimpleXML", "soap", "sockets", "sodium", "SPL", "standard",
              "superglobals", "sysvsem", "sysvshm", "tokenizer", "xml", "xdebug", "xmlreader",
              "xmlwriter", "yaml", "zip", "zlib", "wordpress", "phpunit"
            }
          }
        }
      })
    end,
    volar = function()
      require('lspconfig').volar.setup({})
    end,
    ts_ls = function()
      local vue_typescript_plugin = require('mason-registry')
          .get_package('vue-language-server')
          :get_install_path()
          .. '/node_modules/@vue/language-server'
          .. '/node_modules/@vue/typescript-plugin'

      require('lspconfig').ts_ls.setup({
        init_options = {
          plugins = {
            {
              name = "@vue/typescript-plugin",
              location = vue_typescript_plugin,
              languages = { 'javascript', 'typescript', 'vue' }
            },
          }
        },
        filetypes = {
          'javascript',
          'javascriptreact',
          'javascript.jsx',
          'typescript',
          'typescriptreact',
          'typescript.tsx',
          'vue',
          'json',
        },
      })
    end,
  },
})

local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'render-markdown' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
  }),
  mapping = cmp.mapping.preset.insert({
    ['<CR>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        if luasnip.expandable() then
          luasnip.expand()
        else
          cmp.confirm({
            select = true,
          })
        end
      else
        fallback()
      end
    end),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.locally_jumpable(1) then
        luasnip.jump(1)
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  init_options = {
    markdown_oxide = {
      keyword_pattern = [[\(\k\| \|\/\|#\)\+]]
    }
  },
})
