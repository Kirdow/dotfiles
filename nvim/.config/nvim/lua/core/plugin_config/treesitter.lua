require'nvim-treesitter'.setup {
    -- A list of parser names, or "all"
    ensure_installed = { "c", "cpp", "lua", "rust", "ruby", "java", "kotlin", "groovy", "vim", "html", "php", "typescript" },

    -- Install parsers synchronously (and applied to `ensure_installed`)
    sync_install = true,
    auto_install = true,
    highlight = {
        enable = true,
    },
}

function custom_foldtext()
    local line = vim.fn.getline(vim.v.foldstart)
    local indent = line:match('^(%s*)')
    local count = vim.v.foldend - vim.v.foldstart - 1
    return indent .. '{…' .. count .. ' lines}'
end

vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.foldtext = 'v:lua.custom_foldtext()'
vim.opt.fillchars:append({ fold = ' ' })
vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function()
        vim.api.nvim_set_hl(0, 'Folded', { link = 'Normal' })
    end,
})
