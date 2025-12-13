vim.api.nvim_create_autocmd({ "VimEnter" }, {
	pattern = { "*" },
	callback = function()
		if vim.g.WebDevIconsUnicodeDecorateFileNodesExactSymbols and vim.g.WebDevIconsUnicodeDecorateFileNodesExactSymbols["robots.txt"] then
			vim.g.WebDevIconsUnicodeDecorateFileNodesExactSymbols["robots.txt"] = nil
			print("Remmoved Robots")
		else
			print("Failed to remove robots")
		end
	end,
})

--[[local update_opacity_group = vim.api.nvim_create_augroup("UpdateOpacity", { clear = true })

function set_transparent_background()
	vim.cmd([[
			highlight EndOfBuffer guibg=NONE ctermbg=NONE
			highlight SignColumn guibg=NONE ctermbg=NONE
			highlight VertSplit guibg=NONE ctermbg=NONE
			highlight SpecialKey guibg=NONE ctermbg=NONE
			highlight NonText guibg=NONE ctermbg=NONE
			highlight NonText guibg=NONE ctermbg=NONE
			highlight Folded guibg=NONE ctermbg=NONE
			highlight LineNr guibg=NONE ctermbg=NONE
			highlight Normal guibg=NONE ctermbg=NONE
			highlight NormalFloat guibg=NONE ctermbg=NONE
			highlight NormalNC guibg=NONE ctermbg=NONE
	])
end

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	group = update_opacity_group,
	callback = set_transparent_background,
})]]
