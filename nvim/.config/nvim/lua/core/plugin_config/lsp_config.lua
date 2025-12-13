require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = { "lua_ls", "rust_analyzer", "ts_ls", "clangd", "gopls" }
})

-- Setup cmp capabilities
local cmp_lsp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
local capabilities = vim.lsp.protocol.make_client_capabilities()
if cmp_lsp_ok then
    capabilities = cmp_lsp.default_capabilities(capabilities)
end

local function enable(lsp, data)
    vim.lsp.enable(lsp)
    if type(data) == 'table' then
        -- Merge capabilities into data
        if not data.capabilities then
            data.capabilities = capabilities
        end
        vim.lsp.config(lsp, data)
    else
        -- If no data provided, still set capabilities
        vim.lsp.config(lsp, { capabilities = capabilities })
    end
end

local function enable_all(lsps)
    if type(lsps) == 'string' then
        enable_all({lsps})
        return
    end

    for i,lsp in ipairs(lsps) do
        enable(lsp)
    end
end

enable('lua_ls', {
    settings = {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            workspace = {
                library = {
                    [vim.fn.expand "$VIMRUNTIME/lua"] = true,
                    [vim.fn.stdpath "config" .. "/lua"] = true,
                },
            },
        },
    }
})

enable('rust_analyzer', {
    settings = {
        ["rust-analyzer"] = {
            imports = {
                granularity = {
                    group = "module",
                },
                prefix = "plain",
            }
        }
    }
})

enable_all({"ts_ls", "clangd", "gopls", "kotlin_language_server", "groovy_language_server"})

-- Disable lspconfig's jdtls - nvim-jdtls handles Java via FileType autocmd
vim.lsp.enable('jdtls', false)

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('UserLspConfig', {}),
    callback = function(ev)
        -- Ensure completion triggered by <C-x><C-o>
        vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

        -- Buffer local mappings
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        local opts = { buffer = ev.buf }
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    end,
})
