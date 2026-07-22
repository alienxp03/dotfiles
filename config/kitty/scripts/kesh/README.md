# kesh

Bubble Tea picker for browsing zoxide projects, Kitty workspaces, tabs, windows, SSH hosts, and active Codex/pi agents.

A single-project Kitty session and its zoxide source are one logical folder row, shown with ``. Multi-project sessions created by Kesh remain separate `` session rows so their individual folder sources stay available for composing another session with `n`. SSH locations use ``. Green means an entry is currently open; the icon does not change for saved or closed state.

Build the binary used directly by `kitty.conf`:

```sh
go build -o kesh .
```

Keys:

The picker starts in normal mode:

- `j` / `k` or `ctrl+j` / `ctrl+k`: select a row
- `space`: toggle a project or SSH host for a new multi-tab session
- `n`: name and create a session with one tab per selected item
- `c`: clone a Git repository into an editable destination and open it
- `l`: expand or descend through session → tabs → windows
- `h`: return to the parent or collapse the current level
- `enter`: open a session, focus a tab, or focus a window
- `s`: safely save the selected open project or workspace's tabs, splits, and working directories
- `S`: additionally save foreground commands so restoring the project or workspace reruns them
- `p`, then `0`–`9`: pin the selected session to a shortcut slot
- `p`, then `x`: unpin the selected session
- `r`: rename the selected workspace, tab, or window; submitting an empty workspace name resets it
- `x`, then `y`: close the selected workspace, tab, or window
- `/`: enter search mode and fuzzy-filter sessions as you type
- `enter` / `esc`: return to command mode while retaining the filter
- `tab` / `shift+tab`: change filter
- `q`: close from command mode; `esc` is a no-op there

Arrow keys remain available for moving through rows and the hierarchy.

The `Agents` filter is a flat, most-recently-focused list of Kitty windows running Codex or pi. It includes a live snapshot of the selected window's terminal:

- `enter`: focus the selected agent window
- `p`: show or hide the terminal preview
- `/`: fuzzy-search agent, project, tab, command, and directory fields

Run `kesh agents` to start directly in this view. Kitty invokes it in a tab for `Cmd+Shift+P`; `Cmd+Shift+O` opens the complete hierarchy in an overlay.

Pinned sessions are stored in `${XDG_STATE_HOME:-~/.local/state}/kesh/pins.json`. Kesh also generates `kitty-pins.conf` beside that file and reloads Kitty whenever pins change. `Cmd+0` through `Cmd+9` therefore invoke Kitty's native `goto_session` action directly, without starting Kesh on every switch.

Saved states are catalogued in `${XDG_STATE_HOME:-~/.local/state}/kesh/saved-sessions.json`, with Kitty snapshots under the adjacent `sessions/` directory. Press `s` on an open named project or workspace and confirm with `y` to save it safely without capturing shell foreground commands. Use `S` for an explicit command-aware snapshot: Kesh lists the detected foreground commands before confirmation, and Kitty reruns them when restoring. Saved entries remain in Kesh after they are closed; pressing `enter` restores a closed entry or focuses it when already open. Use `x`, then `y` on a closed saved entry to delete its snapshot.

The clone destination defaults to `~/workspace`. Override it in `${XDG_CONFIG_HOME:-~/.config}/kesh/config.toml`:

```toml
[clone]
root = "~/workspace"
```

Press `c` to open a form with the Git URL and inferred destination together. Use `tab` to switch fields, edit either value, then press `enter` to clone. After a successful clone, Kesh adds the directory to zoxide and opens its Kitty workspace.

Workspace names are Kesh aliases stored in `${XDG_CONFIG_HOME:-~/.config}/kesh/names.json`. Kitty's internal session identity remains unchanged, so aliases can be edited without recreating a live session. Search matches both the alias and the original project or SSH name.
