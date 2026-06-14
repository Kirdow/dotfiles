-- C# / Unity via roslyn.nvim (Microsoft.CodeAnalysis.LanguageServer)
-- Install LSP: ensure Crashdummyy mason registry (see lsp_config.lua) then `:MasonInstall roslyn`
-- Unity: install com.unity.ide.visualstudio, enable "Generate .csproj files",
--        Regenerate project files, then open nvim from the project root (where .sln lives).
local roslyn_ok, roslyn = pcall(require, 'roslyn')
if not roslyn_ok then
    return
end

-- cmp capabilities (matches jdtls.lua / lsp_config.lua)
local cmp_lsp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
local capabilities = vim.lsp.protocol.make_client_capabilities()
if cmp_lsp_ok then
    capabilities = cmp_lsp.default_capabilities(capabilities)
end

roslyn.setup({
    -- Unity source lives under Assets/; .sln sits at project root -> search upward
    broad_search = true,
    -- remember chosen solution per project across sessions
    lock_target = true,
})

-- Global LspAttach autocmd in lsp_config.lua already wires gd/gr/K/etc.
vim.lsp.config('roslyn', {
    capabilities = capabilities,
    settings = {
        ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'fullSolution',
            dotnet_compiler_diagnostics_scope = 'fullSolution',
        },
        ['csharp|inlay_hints'] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
        },
        ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
        },
        ['csharp|completion'] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
            dotnet_show_name_completion_suggestions = true,
        },
    },
})
