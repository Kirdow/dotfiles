require'nvim-treesitter.configs'.setup {
    -- A list of parser names, or "all"
    ensure_installed = { "c", "lua", "rust", "ruby", "java", "kotlin", "vim", "html", "php" },

    -- Install parsers synchronously (and applied to `ensure_installed`)
    sync_install = true,
    auto_install = true,
    highlight = {
        enable = true,
    },
}
