-- debugger
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "leoluz/nvim-dap-go",
    "rcarriga/nvim-dap-ui",
    "theHamsta/nvim-dap-virtual-text",
  },
  keys = {
    { "<leader>dt", '<cmd>lua require"dap-go".debug_test()<CR>', desc = "Debug test" },
    { "<leader>db", '<cmd>lua require"dap".toggle_breakpoint()<CR>', desc = "Toggle breakpoint" },
    { "<leader>do", '<cmd>lua require("dapui").open()<CR>', desc = "Open DAP UI" },
    { "<leader>dx", '<cmd>lua require("dapui").close()<CR>', desc = "Close DAP UI" },
    { "<leader>dc", '<cmd>lua require"dap".continue()<CR>', desc = "Continue" },
    { "<leader>dr", '<cmd>lua require"dap".repl.open()<CR>', desc = "Open REPL" },
    { "<leader>dn", '<cmd> lua require"dap".step_over()<CR>', desc = "Step over" },
    { "<leader>di", '<cmd> lua require"dap".step_into()<CR>', desc = "Step into" },
    { "<leader>du", '<cmd> lua require"dap".step_out()<CR>', desc = "Step out" },
    { "<F9>", function() require("dap").step_over() end, desc = "Step over" },
    { "<F10>", function() require("dap").step_into() end, desc = "Step into" },
    { "<F11>", function() require("dap").step_out() end, desc = "Step out" },
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
