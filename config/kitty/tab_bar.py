import re

from kitty.tab_bar import as_rgb, draw_tab_with_powerline
from kitty.utils import color_as_int


def display_session_name(name):
    # Kesh composed sessions use kesh-<name>--<unique suffix>.
    if name.startswith("kesh-") and "--" in name:
        return name[5:].split("--", 1)[0]

    # Kesh workspace session files append an eight-character content hash.
    match = re.fullmatch(r"(.+)-[0-9a-f]{8}", name)
    if match:
        return match.group(1)
    return name


def draw_tab(draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data):
    end = draw_tab_with_powerline(
        draw_data,
        screen,
        tab,
        before,
        max_tab_length,
        index,
        is_last,
        extra_data,
    )

    if is_last and not extra_data.for_layout:
        session = tab.active_session_name or tab.session_name or "no-session"
        text = f"  {display_session_name(session)}  "
        x = (screen.columns - len(text)) // 2

        # Leave the label out rather than overwriting tabs on narrow windows.
        if x > screen.cursor.x + 1:
            screen.cursor.x = x
            screen.cursor.fg = as_rgb(color_as_int(draw_data.inactive_fg))
            screen.cursor.bg = as_rgb(color_as_int(draw_data.default_bg))
            screen.cursor.bold = False
            screen.cursor.italic = False
            screen.draw(text)

    return end
