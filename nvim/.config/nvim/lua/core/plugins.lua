local ensure_packer = function()
    local fn = vim.fn
    local install_path = fn.stdpath('data')..'/site/pack/packet/start/packer.nvim'
    if fn.empty(fn.glob(install_path)) > 0 then
        fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
        vim.cmd [[packadd packer.nvim]]
        return true
    end
    return false
end

local packer_bootstrap = ensure_packer()

return require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'preservim/nerdtree'
    use 'ryanoasis/vim-devicons'
    use 'tpope/vim-commentary'
    use 'vim-airline/vim-airline'
    use 'rafi/awesome-vim-colorschemes'
    use {
        'nvim-treesitter/nvim-treesitter',
        lazy = false,
        build = ':TSUpdate'
    }
    use 'nvim-lua/plenary.nvim'
    use 'sindrets/diffview.nvim'
    use 'neogitorg/neogit'
    use 'nvim-tree/nvim-web-devicons'

    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "neovim/nvim-lspconfig"
    }

    use 'mfussenegger/nvim-jdtls'
    use 'seblyng/roslyn.nvim'

    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'

    use {
        'nvim-telescope/telescope.nvim',
        tag = 'v0.2.2',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    use 'kirdow/gruvbox.nvim'
    --use 'navarasu/onedark.nvim'
    use {
        'sainnhe/gruvbox-material',
        commit = '90f5d20'
        --commit = '1cfbad9'
    }

    use {
        'kirdow/claude-code.nvim',
        requires = {
            'nvim-lua/plenary.nvim',
        },
        config = function()
            require('claude-code').setup({
                command = "./claude.sh",
            })
        end
    }

    use {
        '3rd/image.nvim',
        config = function()
            require('image').setup({
                backend = "kitty",
            })
        end
    }

    if packer_bootstrap then
        require('packer').sync()
    end
end)
