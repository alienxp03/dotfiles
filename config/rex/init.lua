-- Move Rex's session switcher; let Cmd+K reach the terminal.
rex.unbind("cmd+k")
rex.bind("shift+cmd+k", "session.switch")

-- Raptor plugin logic lives in its own repository; keep local bindings here.
require("raptor").setup{}
rex.bind("shift+cmd+o", "raptor")
rex.bind("shift+cmd+t", "raptor_wt")
rex.bind("cmd+p", "raptor_last_pane")

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
