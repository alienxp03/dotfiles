"""Notify Kesh after Kitty exits normally; Kesh owns all pin state."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any


def on_load(_boss: Any, _data: dict[str, Any]) -> None:
    """Start a Kesh run, clearing pins left by a force-terminated Kitty."""
    subprocess.run(
        [str(Path(__file__).with_name("kesh")), "begin-run"],
        check=False,
        env={**os.environ, "KESH_KITTY_PID": str(os.getpid())},
    )


def on_quit(_boss: Any, _window: Any, data: dict[str, Any]) -> None:
    """Run Kesh only after Kitty's quit request has been confirmed."""
    if data.get("confirmed"):
        subprocess.run([str(Path(__file__).with_name("kesh")), "clear-pins", "--on-quit"], check=False)
