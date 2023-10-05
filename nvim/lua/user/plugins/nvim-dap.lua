-- debugger
return {
	"leoluz/nvim-dap-go",
	ft = "go",
	dependencies = {
		"mfussenegger/nvim-dap",
		"rcarriga/nvim-dap-ui",
		"theHamsta/nvim-dap-virtual-text",
	},
	config = function()
		require("dap-go").setup()
		require("nvim-dap-virtual-text").setup()
		local dapui = require("dapui")
		local dap = require("dap")

		dapui.setup()

		-- Icons
		vim.fn.sign_define("DapBreakpoint", { text = "🟥", texthl = "", linehl = "", numhl = "" })
		vim.fn.sign_define("DapStopped", { text = "▶️", texthl = "", linehl = "", numhl = "" })

		-- Keymaps
		vim.keymap.set("n", "<leader>dt", '<cmd>lua require"dap-go".debug_test()<CR>')
		vim.keymap.set("n", "<leader>db", '<cmd>lua require"dap".toggle_breakpoint()<CR>')
		vim.keymap.set("n", "<leader>do", '<cmd>lua require("dapui").open()<CR>')
		vim.keymap.set("n", "<leader>dx", '<cmd>lua require("dapui").close()<CR>')
		vim.keymap.set("n", "<leader>dc", '<cmd>lua require"dap".continue()<CR>')
		vim.keymap.set("n", "<leader>dr", '<cmd>lua require"dap".repl.open()<CR>')
		vim.keymap.set("n", "<leader>dn", '<cmd> lua require"dap".step_over()<CR>')
		vim.keymap.set("n", "<leader>di", '<cmd> lua require"dap".step_into()<CR>')
		vim.keymap.set("n", "<leader>du", '<cmd> lua require"dap".step_out()<CR>')
		vim.keymap.set("n", "<F9>", require("dap").step_over)
		vim.keymap.set("n", "<F10>", require("dap").step_into)
		vim.keymap.set("n", "<F11>", require("dap").step_out)

		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close()
		end
		dap.listeners.before.event_exited["dapui_config"] = function()
			dapui.close()
		end

		dap.set_log_level("INFO") -- Helps when configuring DAP, see logs with :DapShowLog

		-- TODO: Hardcoded configurations. Need to find ways to make it universal or local to project
		dap.configurations = {
			go = {
				{
					type = "go", -- Which adapter to use
					name = "Debug", -- Human readable name
					request = "launch", -- Whether to "launch" or "attach" to program
					-- program = "${file}", -- The buffer you are focused on when running nvim-dap
					program = "${workspaceFolder}/cmd/${workspaceFolderBasename}",
					env = {
						SERVICE_CONF = "${workspaceFolder}/config_files/service-conf.json",
						SECRET_CONF = "${workspaceFolder}/vault/secrets",
						SERVICE_NAME = "${workspaceFolderBasename}",
						ALL_DEPRECATED_INITS_MIGRATED = "true",
						MYSQL_HOST = "localhost",
						MYSQL = "localhost",
					},
				},
			},
		}
	end,
}
