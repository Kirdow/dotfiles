vim.g.maploader = ' '
vim.g.maplocalleader = ' '

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.shiftround = true
vim.opt.expandtab = true

vim.wo.number = true
vim.wo.relativenumber = true

vim.keymap.set('n', '<F29>', ':silent !./run.sh<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-g>', ':Neogit<CR>', { noremap = true, silent = false })

vim.keymap.set('n', '<F31>', ':lua RunScriptInTerminal()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<F43>', ':lua RunScriptInTerminal(true)<CR>', { noremap = true, silent = true })

function RunScriptInTerminal(test)
    local win_height = vim.api.nvim_win_get_height(0)
    local term_height = math.floor(win_height * 1)

    vim.cmd('botright ' .. term_height .. 'split')
    if test then
        vim.cmd('terminal ./run.sh --test')
    else
        vim.cmd('terminal ./run.sh')
    end
    vim.cmd('autocmd TermClose <buffer> ++once :q!')
    vim.cmd('startinsert')
end
