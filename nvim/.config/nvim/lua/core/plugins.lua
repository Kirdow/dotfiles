local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', 'https://github.com/folke/lazy.nvim.git', lazypath })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
    'preservim/nerdtree',
    'ryanoasis/vim-devicons',
    'tpope/vim-commentary',
    'vim-airline/vim-airline',
    'rafi/awesome-vim-colorschemes',
    { 'nvim-treesitter/nvim-treesitter', branch = 'main', lazy = false, build = ':TSUpdate' },
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
    'neogitorg/neogit',
    'nvim-tree/nvim-web-devicons',

    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'neovim/nvim-lspconfig',

    'mfussenegger/nvim-jdtls',
    'seblyng/roslyn.nvim',

    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',

    'folke/persistence.nvim',

    { 'nvim-telescope/telescope.nvim', tag = 'v0.2.2', dependencies = { 'nvim-lua/plenary.nvim' } },

    'kirdow/gruvbox.nvim',
    --'navarasu/onedark.nvim',
    { 'sainnhe/gruvbox-material', commit = '90f5d20' --[[commit = '1cfbad9']], priority = 1000 },

    'https://git.ktnuity.com/kirdow/kirdowsimple.nvim',
    'https://git.ktnuity.com/kirdow/kirdowhelp.nvim',

    {
        'kirdow/claude-code.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        opts = { command = './claude.sh' },
    },

    {
        '3rd/image.nvim',
        opts = { backend = 'kitty' },
    },
}, {
    rocks = { enabled = false }
})
