# kesh

Bubble Tea picker for browsing zoxide projects, Kitty sessions, tabs, windows, and SSH hosts.

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
- `r`: rename the selected tab or window
- `/`: enter search mode; typing then fuzzy-filters sessions
- `enter` / `esc`: leave search mode
- `tab` / `shift+tab`: change filter
- `q` / `esc`: close from normal mode

Arrow keys remain available as alternatives to `hjkl`.

Pinned sessions are stored in `${XDG_STATE_HOME:-~/.local/state}/kesh/pins.json`. Kitty invokes `kesh switch 0` through `kesh switch 9` in the background for `Cmd+0` through `Cmd+9`.
