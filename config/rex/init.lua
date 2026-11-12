-- Move Rex's session switcher; use Cmd+K to clear/redraw the terminal.
rex.bind("cmd+k", "pane.send_key", { key = "ctrl+l" })
rex.bind("shift+cmd+k", "session.switch")

-- raptor: START
dofile(os.getenv("HOME") .. "/.config/rex/raptor/init.lua").setup({})
rex.bind("cmd+shift+o", "raptor")
rex.bind("ctrl+shift+n", "raptor_worktree_agent")
rex.bind("cmd+p", "raptor_session_last")

-- Mobile clients have no cmd key; duplicate raptor keys with ctrl.
rex.bind("ctrl+shift+o", "raptor")

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
