vim.o.termguicolors = true

vim.o.background = "dark"
--[[require("gruvbox").setup({
    transparent_mode = true
})]]
--vim.cmd([[ colorscheme gruvbox ]])

--vim.g.gruvbox_material_transparent_background=0

--vim.cmd([[ colorscheme gruvbox-material ]])
require("kirdow-simple").setup({
    transparent = false,
})
vim.cmd([[ colorscheme kirdow-simple ]])
--vim.cmd [[ hi normal guibg=#010101 ]]

