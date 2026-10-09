local ts = require('nvim-treesitter')

ts.setup()

-- Parsers to always have installed (async, no-op if already present)
ts.install({ "c", "cpp", "c_sharp", "lua", "rust", "ruby", "java", "kotlin", "groovy", "vim", "vimdoc", "query", "html", "php", "typescript" })

-- Enable highlighting per buffer, auto installing missing parsers
vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
        local buf = args.buf
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end

        local function start()
            if not vim.api.nvim_buf_is_valid(buf) then return false end
            return pcall(vim.treesitter.start, buf, lang)
        end

        if not start() and vim.tbl_contains(ts.get_available(), lang) then
            ts.install(lang):await(vim.schedule_wrap(start))
        end
    end,
})

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
