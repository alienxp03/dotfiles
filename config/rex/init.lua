-- Move Rex's session switcher; use Cmd+K to clear/redraw the terminal.
rex.bind("cmd+k", "pane.send_key", { key = "ctrl+l" })
rex.bind("shift+cmd+k", "session.switch")

-- raptor: START
dofile(os.getenv("HOME") .. "/.config/rex/raptor/init.lua").setup({})
rex.bind("cmd+shift+o", "raptor")
rex.bind("shift+cmd+n", "raptor_worktree_new")
rex.bind("ctrl+shift+n", "raptor_worktree_agent")
rex.bind("cmd+p", "raptor_session_last")

-- Jump to pinned sessions by stable slot (Raptor manages the slots).
for slot = 1, 9 do
	rex.bind("ctrl+cmd+" .. slot, "raptor_pin_" .. slot)
end

-- Only iOS clients get the Ctrl alternatives to Raptor's Cmd shortcuts.
local function ios_bind(key, action)
	rex.bind(key, function(ctx)
		if not ctx.client_id then
			return false
		end

		local result = rex.call("client.inspect", { client_id = ctx.client_id })
		local info = result and result.client and result.client.info
		if not info or info.platform ~= "ios" then
			return false
		end

		rex.invoke(action)
		return true
	end)
end

ios_bind("ctrl+shift+o", "raptor")
-- ctrl+shift+t is bound below to tuicr's PR review, which dispatches to
-- raptor_worktree_new on iOS clients.

-- raptor: END

-- Move between panes with the Neovim-style home row.
rex.bind("ctrl+h", "pane.focus.left")
rex.bind("ctrl+j", "pane.focus.down")
rex.bind("ctrl+k", "pane.focus.up")
rex.bind("ctrl+l", "pane.focus.right")

-- Open Activity in the quick switcher.
rex.bind("cmd+shift+.", "pane.view_activity")

-- Toggle the sidebar.
rex.bind("cmd+b", "client.sidebar.toggle")

-- Toggle zoom on the focused pane.
rex.bind("cmd+shift+f", "pane.zoom")

-- Review code with tuicr in a floating pane over the active window
-- (ported from herdr's prefix+t / prefix+shift+i popups).
local function tuicr_layer(ctx, command)
	-- Start in the focused pane's working directory, like herdr's popups.
	local cwd
	if ctx.block_id then
		local ok, proc = pcall(rex.call, "block.method", {
			session_id = ctx.session_id,
			block_id = ctx.block_id,
			method = "process",
		})
		if ok and type(proc) == "table" and proc.foreground and proc.foreground.cwd then
			cwd = proc.foreground.cwd
		end
	end

	local options = {
		command = command,
		-- An interactive shell reads ~/.zshrc, which puts mise's shims on PATH.
		interactive = true,
	}
	if cwd then
		options.cwd = cwd
	end

	pcall(rex.call, "session.new_layer", {
		session_id = ctx.session_id,
		bounds = { x = 0.05, y = 0.05, w = 0.9, h = 0.9 },
		focus = true,
		layout = {
			block = {
				flavor = "com.superlogical.terminal.shell",
				label = "tuicr",
				options = options,
			},
		},
	})
	return true
end

-- Ctrl+T: review the working tree.
rex.bind("ctrl+t", function(ctx)
	if not ctx.session_id then
		return false
	end
	return tuicr_layer(ctx, { "tuicr", "--working-tree" })
end)

-- Ctrl+Shift+T: review the branch's open PR. iOS keeps Raptor's worktree action.
rex.bind("ctrl+shift+t", function(ctx)
	if ctx.client_id ~= nil then
		local clients = rex.call("client.list")
		for _, client in ipairs(clients and clients.clients or {}) do
			if client.client_id == ctx.client_id and client.info ~= nil and client.info.platform == "ios" then
				rex.invoke("raptor_worktree_new")
				return true
			end
		end
	end
	if not ctx.session_id then
		return false
	end
	return tuicr_layer(ctx, {
		"sh", "-c",
		'n="$(gh pr view --json number --jq .number)" && exec tuicr pr "$n" || { echo "no open PR for this branch"; exit 1; }',
	})
end)

-- >>> resh >>>
local resh_dir = os.getenv("HOME") .. "/Library/Application Support/resh"
local resh_lua = io.open(resh_dir .. "/resh.lua", "r")
local resh_bin = io.open(resh_dir .. "/resh", "r")
if resh_lua then
	resh_lua:close()
end
if resh_bin then
	resh_bin:close()
end
-- Resh is optional; not every machine has it installed.
if resh_lua and resh_bin then
	dofile(resh_dir .. "/resh.lua")
	rex.exec.start({ resh_dir .. "/resh", "service", "start" }, { detach = true, stdout = false, stderr = false })
end
-- <<< resh <<<
