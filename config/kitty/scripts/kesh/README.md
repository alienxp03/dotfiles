# kesh

Bubble Tea picker for browsing zoxide projects, Kitty sessions, tabs, windows, SSH hosts, and active Codex/Pi agents.

Build the binary used directly by `kitty.conf`:

```sh
go build -o kesh .
```

Keys:

The picker starts in normal mode:

- `ctrl+j` / `ctrl+k`: select a row
- `space`: toggle a project or SSH host for a new multi-tab session
- `n`: name and create a session with one tab per selected item
- `l`: expand or descend through session → tabs → windows
- `h`: return to the parent or collapse the current level
- `enter`: open a session, focus a tab, or focus a window
- `p`, then `0`–`9`: pin the selected session to a shortcut slot
- `p`, then `x`: unpin the selected session
- `r`: rename the selected workspace, tab, or window; submitting an empty workspace name resets it
- `x`, then `y`: close the selected workspace, tab, or window
- Start typing to fuzzy-filter sessions; `/` still enters search mode explicitly
- `enter` / `esc`: leave search mode
- `tab` / `shift+tab`: change filter
- `q` / `esc`: close from normal mode

Arrow keys remain available for moving through rows and the hierarchy.

The `Agents` filter is a flat, most-recently-focused list of Kitty windows running Codex or pi. It includes a live snapshot of the selected window's terminal:

- `enter`: focus the selected agent window
- `p`: show or hide the terminal preview
- Start typing to fuzzy-search agent, project, tab, command, and directory fields

Run `kesh agents` to start directly in this view. Kitty invokes it in a tab for `Cmd+Shift+P`; `Cmd+Shift+O` opens the complete hierarchy in an overlay.

Pinned sessions are stored in `${XDG_STATE_HOME:-~/.local/state}/kesh/pins.json`. Kitty invokes `kesh switch 0` through `kesh switch 9` in the background for `Cmd+0` through `Cmd+9`.

Workspace names are Kesh aliases stored in `~/config/kesh/names.json`. Kitty's internal session identity remains unchanged, so aliases can be edited without recreating a live session. Search matches both the alias and the original project or SSH name.
