# kesh

Bubble Tea picker for browsing zoxide projects, Kitty sessions, tabs, windows, SSH hosts, and active Codex/Pi agents.

Build the binary used directly by `kitty.conf`:

```sh
go build -o kesh .
```

Keys:

The picker starts in normal mode:

- `j` / `k`: select a row
- `l`: expand or descend through session → tabs → windows
- `h`: return to the parent or collapse the current level
- `enter`: open a session, focus a tab, or focus a window
- `p`, then `0`–`9`: pin the selected session to a shortcut slot
- `p`, then `x`: unpin the selected session
- `r`: rename the selected workspace, tab, or window; submitting an empty workspace name resets it
- `x`, then `x` again: confirm closing the selected workspace, tab, or window
- `/`: enter search mode; typing then fuzzy-filters sessions
- `enter` / `esc`: leave search mode
- `tab` / `shift+tab`: change filter
- `q` / `esc`: close from normal mode

Arrow keys remain available as alternatives to `hjkl`.

The `Agents` filter is a flat, most-recently-focused list of Kitty windows running Codex or Pi. It includes a live snapshot of the selected window's terminal:

- `enter`: focus the selected agent window
- `p`: show or hide the terminal preview
- `/`: fuzzy-search agent, project, tab, command, and directory fields

Run `kesh agents` to start directly in this view. Kitty invokes it in an overlay for `Cmd+Shift+P`; `Cmd+Shift+I` opens the complete hierarchy in a tab.

Pinned sessions are stored in `${XDG_STATE_HOME:-~/.local/state}/kesh/pins.json`. Kitty invokes `kesh switch 0` through `kesh switch 9` in the background for `Cmd+0` through `Cmd+9`.

Workspace names are Kesh aliases stored in `~/config/kesh/names.json`. Kitty's internal session identity remains unchanged, so aliases can be edited without recreating a live session. Search matches both the alias and the original project or SSH name.
