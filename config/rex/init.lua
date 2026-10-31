-- Move Rex's session switcher; use Cmd+K to clear/redraw the terminal.
rex.bind("cmd+k", "pane.send_key", { key = "ctrl+l" })
rex.bind("shift+cmd+k", "session.switch")

-- raptor: START
require("raptor").setup({
	-- ui = "terminal",
	-- ui = "gui",
	ui = "auto",
	mobile_bounds = { x = 0.08, y = 0.15, w = 0.84, h = 0.60 },
})
rex.bind("shift+cmd+o", "raptor")
rex.bind("shift+cmd+t", "raptor_worktree_list")
rex.bind("ctrl+o", function(ctx, ev)
    rex.invoke("raptor")
    return true
end)
rex.bind("ctrl+n", function(ctx, ev)
    rex.invoke("raptor_worktree_new")
    return true
end)
rex.bind("cmd+p", "raptor_pane_last")

-- Additional iOS modifier combinations for testing.
rex.bind("ctrl+shift+o", "raptor")
rex.bind("alt+o", "raptor")
rex.bind("alt+shift+o", "raptor")
rex.bind("ctrl+alt+o", "raptor")

-- raptor: END

-- Move between panes with the Neovim-style home row.
rex.bind("ctrl+h", "pane.focus.left")
rex.bind("ctrl+j", "pane.focus.down")
rex.bind("ctrl+k", "pane.focus.up")
rex.bind("ctrl+l", "pane.focus.right")

-- Preserve terminal Ctrl+L (clear/redraw) on a shifted shortcut.
rex.bind("cmd+shift+l", "pane.send_key", { key = "ctrl+l" })

-- Toggle the sidebar.
rex.bind("cmd+b", "client.sidebar.toggle")

-- Toggle zoom on the focused pane.
rex.bind("cmd+shift+f", "pane.zoom")
