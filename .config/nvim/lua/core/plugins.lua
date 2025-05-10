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
    use 'nvim-treesitter/nvim-treesitter'
    use 'nvim-lua/plenary.nvim'
    use 'sindrets/diffview.nvim'
    use 'neogitorg/neogit'
    use 'nvim-tree/nvim-web-devicons'

    use {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "neovim/nvim-lspconfig"
    }

    use {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.4',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    use {
        'neoclide/coc.nvim',
        branch = 'master',
        run = 'npm ci'
    }

    --use 'kirdow/gruvbox.nvim'
    --use 'navarasu/onedark.nvim'
    use 'sainnhe/gruvbox-material'

    if packer_bootstrap then
        require('packer').sync()
    end
end)
