return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		-- import lspconfig plugin
		local lspconfig = require("lspconfig")

		-- import cmp-nvim-lsp plugin
		local cmp_nvim_lsp = require("cmp_nvim_lsp")

		-- used to enable autocompletion (assign to every lsp server config)
		local capabilities = cmp_nvim_lsp.default_capabilities()

		-- Change the Diagnostic symbols in the sign column (gutter)
		-- (not in youtube nvim video)
		local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
		end

		local home_path = os.getenv("HOME")
		local servers = {
			html = {
				filetypes = { "html", "slim" },
			},
			emmet_ls = {
				filetypes = { "html", "typescriptreact", "javascriptreact", "css", "sass", "scss", "less" },
			},
			tsserver = {},
			cssls = {},
			bashls = {},
			docker_compose_language_service = {},
			jsonls = {},
			yamlls = {},
			dockerls = {},
			gopls = {},
			terraformls = {},
			tflint = {},
			lua_ls = {
				settings = { -- custom settings for lua
					Lua = {
						-- make the language server recognize "vim" global
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							-- make language server aware of runtime files
							library = {
								[vim.fn.expand("$VIMRUNTIME/lua")] = true,
								[vim.fn.stdpath("config") .. "/lua"] = true,
							},
						},
					},
				},
			},
			solargraph = {
				cmd = { home_path .. "/.rbenv/shims/solargraph", "stdio" },
				root_dir = lspconfig.util.root_pattern("Gemfile", ".git"),
				init_options = { formatting = true },
				settings = {
					solargraph = {
						autoformat = true,
						completion = true,
						diagnostic = true,
						folding = true,
						references = true,
						rename = true,
						symbols = true,
					},
				},
			},
		}

		for name, config in pairs(servers) do
			if type(config) ~= "table" then
				config = {}
			end

			config = vim.tbl_deep_extend("force", {
				capabilities = capabilities,
			}, config)

			-- lsp.configure(name, config)
			lspconfig[name].setup(config)
		end

		-- ruby_ls: textDocument/diagnostic support until 0.10.0 is released
		_timers = {}
		local function setup_diagnostics(client, buffer)
			if require("vim.lsp.diagnostic")._enable then
				return
			end

			local diagnostic_handler = function()
				local params = vim.lsp.util.make_text_document_params(buffer)
				client.request("textDocument/diagnostic", { textDocument = params }, function(err, result)
					if err then
						local err_msg = string.format("diagnostics error - %s", vim.inspect(err))
						vim.lsp.log.error(err_msg)
					end
					if not result then
						return
					end
					vim.lsp.diagnostic.on_publish_diagnostics(
						nil,
						vim.tbl_extend("keep", params, { diagnostics = result.items }),
						{ client_id = client.id }
					)
				end)
			end

			diagnostic_handler() -- to request diagnostics on buffer when first attaching

			vim.api.nvim_buf_attach(buffer, false, {
				on_lines = function()
					if _timers[buffer] then
						vim.fn.timer_stop(_timers[buffer])
					end
					_timers[buffer] = vim.fn.timer_start(200, diagnostic_handler)
				end,
				on_detach = function()
					if _timers[buffer] then
						vim.fn.timer_stop(_timers[buffer])
					end
				end,
			})
		end

		require("lspconfig").ruby_ls.setup({
			on_attach = function(client, buffer)
				setup_diagnostics(client, buffer)
			end,
		})
	end,
}
