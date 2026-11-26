# Rex configuration

- `init.lua`: keybindings and integrations.
- `lua/raptor.lua`: standalone native session/project launcher.
- `tests/raptor_test.lua`: session/project regression tests.
- `tests/worktree_test.lua`: worktree action regression tests.
- `tests/pins_test.lua`: persistent session-pin regression tests.

Mise dotfiles links `init.lua` and `lua/` into `~/.config/rex/` separately,
leaving installed plugins untouched. The Lua launcher does not depend on the
Raptor checkout, binary, resident host, or state files.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| **⇧⌘O** | Switch open sessions |
| **⇧⌘N** | Zoxide project list / new session |
| **⌃⇧N** | Instant worktree with a random branch name |
| **⌥⌘N** | Worktree with a prompted branch name |

All are three-key chords. Search directly in Rex's native palette; no fzf or
extra query prompt. The session picker never lists directories or creates sessions.
The project picker shows zoxide's frecency list, excluding known open paths.
Select a directory, or enter an absolute path, `~/path`, or a path relative to
the origin terminal. Only the current session has a right-hand **Current** badge.

Open paths are inferred from terminal working directories across windows/panes,
plus destinations remembered until config reload. Exact paths, not basenames,
establish identity. Different symlink spellings or moving all terminals away
from a project can make it appear unopened. The selected directory is validated
and live paths rechecked before creation; an already open project is switched
to instead. New sessions teach zoxide.

The original Raptor plugin setup/bindings and its iOS review fallback are
commented out in `init.lua` for rollback. Its files remain installed, but its
numbered pin shortcuts, last-session, PR, and instant-agent actions are inactive.
Session pins and worktree creation are provided by the Lua actions described below;
the other legacy features are not implemented.

## Session pins

In **⇧⌘O**, choose **Manage pins…** at the bottom. The native multi-select picker
starts with saved pins checked. Toggle sessions, then press **⌘Return** to save.
Save or Cancel returns to the session picker; it does not switch sessions.
Pinned sessions have a subtle native star and are supplied first, preserving Rex’s
original order within pinned/unpinned groups. Rex still controls search scoring.
There is no extra shortcut or inline pin handler.

Pins live in `$XDG_STATE_HOME/rex/raptor-pins.json`, defaulting to
`~/.local/state/rex/raptor-pins.json`. The `pins_file` setup option overrides this.
State is independent of the legacy Raptor pins and is saved by atomic rename.
Pins use session IDs, surviving config reloads and session renames—not deletion
and recreation under the same label. Closed sessions are hidden; saving the pin
editor drops closed IDs. Clearing all checkboxes removes all pins. Cancel changes
nothing. Unreadable/corrupt state or failed saves report an error rather than
silently replacing the file. Only sessions are pinnable, not project directories.

## Worktree creation

Both worktree actions use the origin pane’s repository and committed `HEAD`
(frozen before the prompt), not the default branch. Uncommitted changes stay in
the original checkout. Instant names are `task-` plus eight UUID hex digits,
checked for existing local branches with bounded collision retries. The named
action asks only for a branch name; cancellation does nothing and existing or
invalid branch names are rejected.

A new Rex session runs `wt switch --create --base <commit> --execute <shell>`
in its terminal. Worktrunk owns configured path templates, hook execution and
approvals; there is no hidden hook execution, automatic approval, or agent launch.
On success, a shell starts in the new worktree. Failures leave the terminal
visible for inspection—do not retry blindly, since a worktree may already exist.
The new session initially starts in the source repository while Worktrunk runs.

The `wt`, `git`, `uuidgen`, and `shell` setup options accept executable paths.
This Mac’s config uses Homebrew Git/Worktrunk, system `uuidgen`, and `$SHELL`
(default `/bin/sh`). Git, Worktrunk and `uuidgen` must be installed on the server.

## Requirements and checks

Unix/macOS, local Rex server, native prompts (API revision 17+). The config uses
zoxide's mise shim; change the `zoxide` setup option if installed elsewhere.
Missing zoxide does not affect switching; the project picker still accepts paths.
Native pickers show at most 2,000 rows. Rex controls filtering/ranking and
broadcasts prompts to eligible connected apps; the first answer/cancel wins.
Bind actions directly, not through `rex.invoke` wrappers.

```sh
cd ~/.dotfiles
make test-rex
rex config reload
```

No Raptor build or installation is required.
