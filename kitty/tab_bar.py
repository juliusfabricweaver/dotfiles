# Gruvbox lualine-style tab bar: tabs as sections on the left, date/time on the right
from datetime import datetime

from kitty.boss import get_boss
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title

# lualine's default powerline separators
SECTION_LEFT = ""
SECTION_RIGHT = ""
COMPONENT_LEFT = ""
ICON_DATE = ""
ICON_TIME = ""

# lualine gruvbox_dark "normal" theme: a / b / c sections
A_FG, A_BG = as_rgb(0x282828), as_rgb(0xA89984)
B_FG, B_BG = as_rgb(0xEBDBB2), as_rgb(0x504945)
C_FG, C_BG = as_rgb(0xA89984), as_rgb(0x3C3836)
TIME_FG, TIME_BG = as_rgb(0xFABD2F), as_rgb(0x665C54)

_timer_id = None
_prev_bg = None


def _redraw(_timer_id):
    for tm in get_boss().all_tab_managers:
        tm.mark_tab_bar_dirty()


def _draw_separator(screen: Screen, char: str, fg: int, bg: int) -> None:
    screen.cursor.bold = False
    screen.cursor.fg = fg
    screen.cursor.bg = bg
    screen.draw(char)


def _draw_right_status(screen: Screen) -> None:
    now = datetime.now()
    sections = [
        (B_FG, B_BG, False, f" {ICON_DATE} {now:%d %b} "),
        (TIME_FG, TIME_BG, True, f" {ICON_TIME} {now:%H:%M} "),
    ]
    # each section is a separator plus its text
    width = sum(len(text) + 1 for *_, text in sections)
    if screen.cursor.x + width > screen.columns:
        return
    screen.cursor.bg = C_BG
    screen.draw(" " * (screen.columns - width - screen.cursor.x))
    prev_bg = C_BG
    for fg, bg, bold, text in sections:
        _draw_separator(screen, SECTION_RIGHT, bg, prev_bg)
        screen.cursor.fg = fg
        screen.cursor.bold = bold
        screen.draw(text)
        prev_bg = bg


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    global _timer_id, _prev_bg
    if _timer_id is None:
        _timer_id = add_timer(_redraw, 30, True)

    fg, bg = (A_FG, A_BG) if tab.is_active else (B_FG, B_BG)

    if index == 1:
        _prev_bg = None
    elif _prev_bg == bg:
        _draw_separator(screen, COMPONENT_LEFT, fg, bg)
    else:
        _draw_separator(screen, SECTION_LEFT, _prev_bg, bg)

    screen.cursor.fg = fg
    screen.cursor.bg = bg
    screen.cursor.bold = tab.is_active
    draw_title(draw_data, screen, tab, index, max_title_length)
    _prev_bg = bg

    if is_last:
        _draw_separator(screen, SECTION_LEFT, bg, C_BG)
    end = screen.cursor.x

    if is_last:
        _draw_right_status(screen)
    return end
