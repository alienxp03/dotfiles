# Agents

## Testing Neovim Changes

Before applying any changes to Neovim config files, you MUST verify them using `nvim --headless`. Do not blindly edit config and hope it works.

### Checking available APIs

Inspect a module's exported functions before using them:

```bash
nvim --headless -c 'lua print(vim.inspect(require("module.name")))' -c 'qa!' 2>&1
```

### Testing Lua expressions

Run arbitrary Lua to verify logic, check values, or confirm functions exist:

```bash
nvim --headless -c 'lua local ok, err = pcall(function() --[[ your code ]] end); print(ok, err)' -c 'qa!' 2>&1
```

### Verifying config loads without errors

`nvim --headless -c 'qa!'` is NOT sufficient — lazy.nvim catches plugin errors and shows them via its notification UI, which doesn't render in headless mode.

Use a detached tmux session to open nvim and capture the output without disrupting the user's workflow:

```bash
# Open nvim in a detached session with a test file
tmux new-session -d -s nvim-test 'nvim test.ts'

# Wait for plugins to load, then capture the pane
sleep 3 && tmux capture-pane -t nvim-test -p

# Clean up
tmux send-keys -t nvim-test ':qa!' Enter && sleep 1 && tmux kill-session -t nvim-test
```

This captures the actual lazy.nvim error notifications as they appear. Always run this after making changes to any plugin config.

### Key rules

- Always check that a function/method exists on a module before using it in config
- Use `pcall` to test code that might error
- Test the fix logic in `--headless` mode before writing it to the config file
- Neovim plugins are located at `~/.local/share/nvim/lazy/`
- If a plugin API is unclear, read its source directly from the lazy directory
