-- Move Rex's session switcher; use Cmd+K to clear/redraw the terminal.
rex.bind("cmd+k", "pane.send_key", { key = "ctrl+l" })
rex.bind("shift+cmd+k", "session.switch")

-- raptor: START
-- Keep modules discoverable when tools validate this symlink's dotfiles target.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
package.path = config_home .. "/rex/?.lua;" .. config_home .. "/rex/?/init.lua;" .. package.path
require("raptor").setup({
	bin = os.getenv("HOME") .. "/.local/bin/raptor",
	app = os.getenv("HOME") .. "/Applications/Raptor.app",
	ui = "auto",
	mobile_bounds = { x = 0.08, y = 0.15, w = 0.84, h = 0.60 },
})
rex.bind("shift+cmd+t", "raptor_worktree_list")
rex.bind("cmd+shift+o", function(ctx, ev)
	rex.invoke("raptor")
	return true
end)
rex.bind("cmd+shift+a", function(ctx, ev)
	rex.invoke("raptor_agents")
	return true
end)
rex.bind("cmd+shift+s", function(ctx, ev)
	rex.invoke("raptor_sessions")
	return true
end)
-- Create an auto-named worktree and start fresh Pi without a picker.
rex.bind("ctrl+shift+n", function(ctx, ev)
	rex.invoke("raptor_task_new")
	return true
end)
-- Experimental two-stage path → action launcher.
rex.bind("ctrl+m", function(ctx, ev)
	rex.invoke("raptor_launcher")
	return true
end)
rex.bind("cmd+p", "raptor_pane_last")

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
