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

local function InitKeymap()
    vim.keymap.set('n', '<F29>', ':silent !./run.sh<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<C-g>', ':Neogit<CR>', { noremap = true, silent = false })

    vim.keymap.set('n', '<F31>', ':lua RunScriptInTerminal()<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<F43>', ':lua RunScriptInTerminal(true)<CR>', { noremap = true, silent = true })

    vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', { desc = 'Toggle Claude Code' })
    vim.keymap.set('n', '<leader>fc', ':lua FixComment()<CR>', { noremap = true, silent = true })

    vim.keymap.set('n', '<leader>cs', ':lua ToggleColorScheme()<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<leader>tt', ':lua ToggleThemeTransparency()<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<leader>ss', CreateScreenshotToggle('gruvbox-material'), { noremap = true, silent = true })

    vim.keymap.set('n', '<leader>fe', ':lua FixEolToggle()<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<leader>fi', ':lua FixIndent()<CR>', { noremap = true, silent = true })
    vim.keymap.set('n', '<leader>ti', ':lua ToggleImages()<CR>', { noremap = true, silent = true })

    vim.keymap.set('n', '<leader>sc', ':lua SpawnConsole()<CR>', { noremap = true, silent = true })
    vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]])

    vim.keymap.set('n', 'zz', 'za', { noremap = true, silent = true })

    -- load the session for the current directory
    vim.keymap.set('n', '<leader>qs', function() require("persistence").load() end)

    -- select a session to load
    vim.keymap.set('n', '<leader>qS', function() require("persistence").select() end)

    -- load the last session
    vim.keymap.set('n', '<leader>ql', function() require("persistence").load({ last = true }) end)

    -- stop Persistence => session won't be saved on exit
    vim.keymap.set('n', '<leader>qd', function() require("persistence").stop() end)
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function SpawnConsole()
    local win_width = vim.api.nvim_win_get_width(0)
    local term_width = math.floor(win_width * 0.5)

    vim.cmd('botright ' .. term_width .. 'vsplit')
    vim.cmd('terminal')
end

function RunScriptInTerminal(test)
    local win_height = vim.api.nvim_win_get_height(0)
    local term_height = math.floor(win_height * 1)
    local uname = vim.uv.os_uname().sysname
    local is_windows = uname == "Win32"
    local is_linux = uname == "Linux"
    local is_macos = uname == "Darwin"

    vim.cmd('botright ' .. term_height .. 'split')
    local cwd = vim.fn.getcwd()
    if cwd:find('probe/kirbot') then
        vim.cmd('terminal bash -c "./validate.sh; read -rp \\"Press Enter to close...\\" "')
    elseif cwd:find('probe/simgame') then
        local build = nil
        local run = './SimGame'
        if file_exists("./scripts/build-linux.sh") and is_linux then
            build = "./scripts/build-linux.sh"
        elseif file_exists("./scripts/build-macos.sh") and is_macos then
            build = "./scripts/build-macos.sh"
        elseif file_exists("./scripts/build-windows.sh") and is_windows then
            build = "./scripts/build-windows.sh"
            run = "./SimGame.exe"
        end

        if build ~= nil then
            vim.cmd('terminal ' .. build .. ' && ' .. run)
        end
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
    elseif vim.g.colors_name == 'kirdow-simple' then
        require('kirdow-simple').toggle_transparent()
    end
end

function ToggleColorScheme()
    if vim.g.colors_name == 'gruvbox-material' then
        vim.cmd [[ colorscheme gruvbox ]]
    elseif vim.g.colors_name == 'gruvbox' then
        vim.cmd [[ colorscheme gruvbox-material ]]
    elseif vim.g.colors_name == 'kirdow-simple' or vim.g.colors_name == 'kirdow-simple-dark' then
        if require('kirdow-simple').is_transparent() then
            require('kirdow-simple').toggle_transparent()
        end
        vim.cmd [[ colorscheme kirdow-simple-light ]]
    elseif vim.g.colors_name == 'kirdow-simple-light' then
        vim.cmd [[ colorscheme kirdow-simple ]]
    end
end


function CreateScreenshotToggle(screenshot_theme)
    local changing = false
    local is_mode = nil

    local function TryApplyColorscheme(name)
        local current = vim.g.colors_name
        local ok, err = pcall(vim.cmd.colorscheme, name)
        if not ok then
            if err:match("E185") then
                return false
            end

            ok, err = pcall(vim.cmd.colorscheme, current)
            if not ok then
                vim.notify("Failed to set colorscheme '" .. tostring(name) .. "'. Revertion to '" .. tostring(current) .. "' also failed.", vim.log.levels.ERROR)
            end

            return false
        end

        return true
    end

    local function Toggle()
        changing = true
        if is_mode ~= nil and type(is_mode) == "string" then
            TryApplyColorscheme(is_mode)
            is_mode = nil
            vim.notify("Screenshot Mode: Off", vim.log.levels.INFO)
        else
            if vim.g.colors_name == screenshot_theme then
                vim.notify("Screenshot Mode: Unchanged", vim.log.levels.INFO)
                changing = false
                return
            end

            is_mode = vim.g.colors_name
            TryApplyColorscheme(screenshot_theme)
            vim.notify("Screenshot Mode: On", vim.log.levels.INFO)
        end
        changing = false
    end

    local group = vim.api.nvim_create_augroup("ColorschemeWatcher_SS_" .. screenshot_theme, { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function(args)
            if not changing then
                if is_mode ~= nil then
                    vim.notify("Screenshot Mode: Aborted", vim.log.levels.INFO)
                    is_mode = nil
                end
            end
        end,
    })

    return Toggle
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
        vim.cmd('%s/^' .. tabs .. '/' .. spaces .. '/ge')
    end
end

InitKeymap()
