vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

--vim.opt.binary = true
--vim.opt.fixeol = false

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

vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', { desc = 'Toggle Claude Code' })
vim.keymap.set('n', '<leader>fc', ':lua FixComment()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<leader>cs', ':lua ToggleThemeTransparency()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>fe', ':lua FixEolToggle()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>fi', ':lua FixIndent()<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>ti', ':lua ToggleImages()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', 'zz', 'za', { noremap = true, silent = true })

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function RunScriptInTerminal(test)
    local win_height = vim.api.nvim_win_get_height(0)
    local term_height = math.floor(win_height * 1)

    vim.cmd('botright ' .. term_height .. 'split')
    local cwd = vim.fn.getcwd()
    if cwd:find('probe/kirbot') then
        vim.cmd('terminal bash -c "./validate.sh; read -rp \\"Press Enter to close...\\" "')
    elseif test then
        if file_exists("./run.sh") then
            vim.cmd('terminal ./run.sh --test')
        elseif file_exists("./run") then
            vim.cmd('terminal ./run --test')
        else
            --print("./run or ./run.sh not found")
        end
    else
        local prefix = ''
        if file_exists("./build.sh") then
            prefix = './build.sh && '
        elseif file_exists("./build") then
            prefix = './build && '
        end

        if file_exists("./run.sh") then
            vim.cmd('terminal ' .. prefix .. './run.sh')
        elseif file_exists("./run") then
            vim.cmd('terminal ' .. prefix .. './run')
        else
            --print("./run or ./run.sh not found")
        end
    end
    vim.cmd('autocmd TermClose <buffer> ++once :q!')
    vim.cmd('startinsert')
end

function ToggleThemeTransparency()
    if vim.g.colors_name == 'gruvbox-material' then
        vim.cmd.colorscheme('gruvbox')
    elseif vim.g.colors_name == 'gruvbox' then
        vim.cmd.colorscheme('gruvbox-material')
    end
end

function FixComment()
    local filename = vim.fn.expand('%')
    if #filename == 0 then
        print("No file open")
        return
    end
    local line = vim.fn.line('.')

    -- ClaudeCode \"/fix-comment\ cmd/cli/main.go\ 9\"
    -- local prompt = "\"/fix-comment\\ " .. filename .. "\\ " .. line .. "\""
    local filePrompt = filename
    if filename:find(' ') then
        filePrompt = "\"" .. filename:gsub(" ", "\\ ") .. "\""
    end
    local prompt = "'/fix-comment " .. filePrompt .. " " .. line .. "'"
    local cmd = 'ClaudeCode ' .. prompt
    vim.cmd(cmd)
end

function FixEolToggle()
    if vim.bo.fixeol then
        vim.bo.fixeol = false
        print("auto EOL: off")
    else
        vim.bo.fixeol = true
        print("auto EOL: on")
    end
end

function ToggleImages()
    local img = require("image")
    if img.is_enabled() then
        img.disable()
        print("images: off")
    else
        img.enable()
        print("images: on")
    end
end

function FixIndent()
    vim.cmd('%s/ \\+$//ge')
    for i = 16, 1, -1 do
        local tabs = string.rep("\\t", i)
        local spaces = string.rep("    ", i)
        vim.cmd('%s/^' .. spaces .. '/' .. tabs .. '/ge')
    end
end
