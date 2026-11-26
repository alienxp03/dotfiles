# Rex configuration

- `init.lua`: keybindings and integrations.
- `lua/raptor.lua`: standalone native session/project launcher.
- `tests/raptor_test.lua`: launcher regression tests.

Mise dotfiles links `init.lua` and `lua/` into `~/.config/rex/` separately,
leaving installed plugins untouched. The Lua launcher does not depend on the
Raptor checkout, binary, resident host, or state files.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| **⇧⌘O** | Switch open sessions |
| **⇧⌘N** | Zoxide project list / new session |

Both are three-key chords. Search directly in Rex's native palette; no fzf or
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
pins, last-session, worktree, PR, and instant-agent actions are inactive.
The Lua launcher does not implement those features.

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
