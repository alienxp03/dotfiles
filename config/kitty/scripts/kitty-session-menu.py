#!/usr/bin/env python3
"""Build Kitty's project/session picker menu with minimal subprocess overhead."""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path


def run(*args: str) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value)


def main() -> int:
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} KITTY SOCKET HOME", file=sys.stderr)
        return 2

    kitty, socket, home_arg = sys.argv[1:]
    home = Path(home_arg)
    state = json.loads(run(kitty, "@", "--to", socket, "ls"))

    open_paths: dict[str, float] = {}
    sessions_by_path: dict[str, str] = {}
    session_names: set[str] = set()
    session_alias_paths: set[str] = set()
    open_sessions: dict[str, tuple[str, float]] = {}
    open_ssh_hosts: dict[str, float] = {}

    for os_window in state:
        for tab in os_window.get("tabs", []):
            windows = tab.get("windows", [])
            named_windows = [window for window in windows if window.get("session_name")]
            tab_session = named_windows[0].get("session_name") if named_windows else ""
            if tab_session:
                session_names.add(tab_session)
                canonical_window = named_windows[0]
                canonical_path = (canonical_window.get("env") or {}).get(
                    "PWD"
                ) or canonical_window.get("cwd", "")
                previous_path, previous_focus = open_sessions.get(
                    tab_session, (canonical_path, 0)
                )
                latest_focus = max(
                    [previous_focus]
                    + [window.get("last_focused_at") or 0 for window in windows]
                )
                open_sessions[tab_session] = (previous_path, latest_focus)

                for window in windows:
                    path = (window.get("env") or {}).get("PWD") or window.get("cwd") or ""
                    if path and path != previous_path:
                        session_alias_paths.add(path)

            for window in windows:
                for process in window.get("foreground_processes", []):
                    command = process.get("cmdline") or []
                    if len(command) > 1 and (command[0] == "ssh" or command[0].endswith("/ssh")):
                        host = command[1]
                        open_ssh_hosts[host] = max(
                            open_ssh_hosts.get(host, 0),
                            window.get("last_focused_at") or 0,
                        )

    for session, (path, last_focused_at) in open_sessions.items():
        if path and not session.startswith("ssh-"):
            sessions_by_path[path] = session
            open_paths[path] = last_focused_at

    entries: list[tuple[bool, float, int, bool, str]] = []
    projects: list[tuple[int, float, int, str]] = []
    for index, path in enumerate(run("zoxide", "query", "-l").splitlines()):
        if path and path != "/" and path not in session_alias_paths:
            is_open = path in open_paths
            projects.append((0 if is_open else 1, -open_paths.get(path, 0), index, path))

    projects.sort(key=lambda item: (item[0], item[1], item[2]))
    order = 0
    for _, _, _, path in projects:
        name = Path(path).name
        display_path = "~" if path == str(home) else path
        home_prefix = f"{home}/"
        if path.startswith(home_prefix):
            display_path = f"~/{path[len(home_prefix):]}"
        is_open = path in open_paths
        existing = sessions_by_path.get(path, "-")
        taken = "1" if safe_name(name) in session_names else "0"
        line = f"{path}\t{'●' if is_open else '○'} {name:<28}\t{display_path}\t{existing}\t{taken}"
        entries.append((is_open, open_paths.get(path, 0), order, False, line))
        order += 1

    ssh_config = home / ".ssh" / "config"
    if ssh_config.is_file():
        host_options: dict[str, dict[str, str]] = {}
        current_hosts: list[str] = []
        for raw_line in ssh_config.read_text(errors="replace").splitlines():
            try:
                parts = shlex.split(raw_line, comments=True)
            except ValueError:
                continue
            if not parts:
                continue
            keyword = parts[0].lower()
            if keyword == "host":
                current_hosts = [host for host in parts[1:] if not re.search(r"[*?!]", host)]
                for host in current_hosts:
                    host_options.setdefault(host, {})
            elif keyword in ("user", "hostname", "port") and len(parts) > 1:
                for host in current_hosts:
                    host_options[host].setdefault(keyword, parts[1])

        default_user = os.environ.get("USER", "")
        for host in sorted(host_options):
            is_open = host in open_ssh_hosts
            options = host_options[host]
            user = options.get("user", default_user)
            hostname = options.get("hostname", host).replace("%h", host)
            port = options.get("port", "22")
            target = f"{user}@{hostname}:{port}" if user else f"{hostname}:{port}"
            session = f"ssh-{safe_name(host)}" if is_open else "-"
            line = f"ssh://{host}\t{'●' if is_open else '○'} {host:<28}\t{target}\t{session}\t0"
            entries.append((is_open, open_ssh_hosts.get(host, 0), order, True, line))
            order += 1

    # Keep open sessions in most-recently-used order. Put closed SSH hosts
    # before closed projects to favor direct host-name matches.
    entries.sort(
        key=lambda entry: (
            not entry[0],
            -entry[1] if entry[0] else 0,
            0 if not entry[0] and entry[3] else 1,
            entry[2],
        )
    )
    print("\n".join(entry[4] for entry in entries))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
