local jdtls_ok, jdtls = pcall(require, 'jdtls')
if not jdtls_ok then
    return
end

-- Setup cmp capabilities for jdtls
local cmp_lsp_ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
local capabilities = vim.lsp.protocol.make_client_capabilities()
if cmp_lsp_ok then
    capabilities = cmp_lsp.default_capabilities(capabilities)
end

local jdtls_dir = vim.fn.stdpath('data') .. '/mason/packages/jdtls'
local config_dir = jdtls_dir .. '/config_linux'
local plugins_dir = jdtls_dir .. '/plugins/'
local path_to_jar = plugins_dir .. 'org.eclipse.equinox.launcher_*.jar'
local lombok_path = jdtls_dir .. '/lombok.jar'

local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts" }

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        local root_dir = require('jdtls.setup').find_root(root_markers)
        if root_dir == "" or root_dir == nil then
            root_dir = vim.fn.getcwd()
        end

        local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
        local workspace_dir = vim.fn.stdpath('data') .. '/jdtls-workspace/' .. project_name

        local bundles = {}

        -- java-debug bundle
        local java_debug_path = vim.fn.stdpath('data') .. '/java-debug/com.microsoft.java.debug.plugin/target/com.microsoft.java.debug.plugin-*.jar'
        local debug_jars = vim.split(vim.fn.glob(java_debug_path, true), "\n")
        for _, jar in ipairs(debug_jars) do
            if jar ~= "" then
                table.insert(bundles, jar)
            end
        end

        -- java-test bundle
        local java_test_path = vim.fn.stdpath('data') .. '/vscode-java-test/server/*.jar'
        local test_jars = vim.split(vim.fn.glob(java_test_path, true), "\n")
        for _, jar in ipairs(test_jars) do
            if jar ~= "" then
                table.insert(bundles, jar)
            end
        end

        local on_attach = function(client, bufnr)
            -- Additional jdtls-specific keybindings
            local opts = { buffer = bufnr, silent = true }
            vim.keymap.set('n', '<leader>jo', "<Cmd>lua require'jdtls'.organize_imports()<CR>", opts)
            vim.keymap.set('n', '<leader>jv', "<Cmd>lua require'jdtls'.extract_variable()<CR>", opts)
            vim.keymap.set('v', '<leader>jv', "<Esc><Cmd>lua require'jdtls'.extract_variable(true)<CR>", opts)
            vim.keymap.set('n', '<leader>jc', "<Cmd>lua require'jdtls'.extract_constant()<CR>", opts)
            vim.keymap.set('v', '<leader>jc', "<Esc><Cmd>lua require'jdtls'.extract_constant(true)<CR>", opts)
            vim.keymap.set('v', '<leader>jm', "<Esc><Cmd>lua require'jdtls'.extract_method(true)<CR>", opts)
        end

        local config = {
            cmd = {
                'java',
                '-Declipse.application=org.eclipse.jdt.ls.core.id1',
                '-Dosgi.bundles.defaultStartLevel=4',
                '-Declipse.product=org.eclipse.jdt.ls.core.product',
                '-Dlog.protocol=true',
                '-Dlog.level=ALL',
                '-javaagent:' .. lombok_path,
                '-Xms1g',
                '--add-modules=ALL-SYSTEM',
                '--add-opens', 'java.base/java.util=ALL-UNNAMED',
                '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

                '-jar', vim.fn.glob(path_to_jar),
                '-configuration', config_dir,
                '-data', workspace_dir,
            },

            root_dir = root_dir,

            settings = {
                java = {
                    eclipse = {
                        downloadSources = true,
                    },
                    configuration = {
                        updateBuildConfiguration = "interactive",
                    },
                    maven = {
                        downloadSources = true,
                    },
                    implementationsCodeLens = {
                        enabled = true,
                    },
                    referencesCodeLens = {
                        enabled = true,
                    },
                    references = {
                        includeDecompiledSources = true,
                    },
                    format = {
                        enabled = true,
                    },
                },
                signatureHelp = { enabled = true },
                completion = {
                    favoriteStaticMembers = {
                        "org.hamcrest.MatcherAssert.assertThat",
                        "org.hamcrest.Matchers.*",
                        "org.hamcrest.CoreMatchers.*",
                        "org.junit.jupiter.api.Assertions.*",
                        "java.util.Objects.requireNonNull",
                        "java.util.Objects.requireNonNullElse",
                        "org.mockito.Mockito.*",
                    },
                },
                contentProvider = { preferred = 'fernflower' },
                extendedClientCapabilities = jdtls.extendedClientCapabilities,
                sources = {
                    organizeImports = {
                        starThreshold = 9999,
                        staticStarThreshold = 9999,
                    },
                },
                codeGeneration = {
                    toString = {
                        template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                    },
                    useBlocks = true,
                },
            },

            flags = {
                allow_incremental_sync = true,
            },

            init_options = {
                bundles = bundles,
            },

            on_attach = on_attach,
            capabilities = capabilities,
        }

        jdtls.start_or_attach(config)
    end,
})
