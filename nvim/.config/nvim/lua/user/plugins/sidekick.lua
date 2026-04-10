return {
  "folke/sidekick.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    -- add any options here
    cli = {
      mux = {
        backend = "zellij",
        enabled = true,
      },
    },
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
    {
      "<c-.>",
      function()
        require("sidekick.cli").focus()
      end,
      desc = "Sidekick Focus",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "Sidekick Toggle CLI",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select()
      end,
      -- Or to select only installed tools:
      -- require("sidekick.cli").select({ filter = { installed = true } })
      desc = "Select CLI",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "Detach a CLI Session",
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("sidekick.cli").send({ msg = "{selection}" })
      end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    -- Example of a keybinding to open Claude directly
    {
      "<leader>ac",
      function()
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "Sidekick Toggle Claude",
    },
  },
  config = function(_, opts)
    local copilot_cmd = vim.fn.stdpath("data") .. "/mason/bin/copilot-language-server"

    local function sign_in(bufnr, client)
      client:request("signIn", vim.empty_dict(), function(err, result)
        if err then
          vim.notify(err.message, vim.log.levels.ERROR)
          return
        end

        if result.command then
          local code = result.userCode
          local command = result.command
          vim.fn.setreg("+", code)
          vim.fn.setreg("*", code)

          local continue = vim.fn.confirm(
            "Copied your one-time code to clipboard.\nOpen the browser to complete the sign-in process?",
            "&Yes\n&No"
          )

          if continue == 1 then
            client:exec_cmd(command, { bufnr = bufnr }, function(cmd_err, cmd_result)
              if cmd_err then
                vim.notify(cmd_err.message, vim.log.levels.ERROR)
                return
              end

              if cmd_result.status == "OK" then
                vim.notify("Signed in as " .. cmd_result.user .. ".")
              end
            end)
          end
        end

        if result.status == "PromptUserDeviceFlow" then
          vim.notify("Enter your one-time code " .. result.userCode .. " in " .. result.verificationUri)
        elseif result.status == "AlreadySignedIn" then
          vim.notify("Already signed in as " .. result.user .. ".")
        end
      end)
    end

    local function sign_out(_, client)
      client:request("signOut", vim.empty_dict(), function(err, result)
        if err then
          vim.notify(err.message, vim.log.levels.ERROR)
          return
        end

        if result.status == "NotSignedIn" then
          vim.notify("Not signed in.")
        end
      end)
    end

    vim.lsp.config("copilot", {
      cmd = { vim.fn.executable(copilot_cmd) == 1 and copilot_cmd or "copilot-language-server", "--stdio" },
      root_markers = { ".git" },
      init_options = {
        editorInfo = {
          name = "Neovim",
          version = tostring(vim.version()),
        },
        editorPluginInfo = {
          name = "Neovim",
          version = tostring(vim.version()),
        },
      },
      settings = {
        telemetry = {
          telemetryLevel = "all",
        },
      },
      on_attach = function(client, bufnr)
        if vim.lsp.inline_completion
          and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr)
        then
          vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
        end

        vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignIn", function()
          sign_in(bufnr, client)
        end, { desc = "Sign in Copilot with GitHub" })

        vim.api.nvim_buf_create_user_command(bufnr, "LspCopilotSignOut", function()
          sign_out(bufnr, client)
        end, { desc = "Sign out Copilot with GitHub" })
      end,
    })

    require("sidekick").setup(opts)
    vim.lsp.enable("copilot")
  end,
}
