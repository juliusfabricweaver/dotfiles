# Gruvbox tab bar with date/time on the right (replaces tmux-gruvbox status)
from datetime import datetime

from kitty.boss import get_boss
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_tab_with_powerline

FG_DARK = 0x282828
FG_LIGHT = 0xA89984
BG_DATE = 0x3C3836
BG_TIME = 0xA89984

_timer_id = None


def _redraw(_timer_id):
    for tm in get_boss().all_tab_managers:
        tm.mark_tab_bar_dirty()


def _draw_right_status(screen: Screen) -> None:
    now = datetime.now()
    cells = [
        (FG_LIGHT, BG_DATE, now.strftime(" %d/%b/%y ")),
        (FG_DARK, BG_TIME, now.strftime(" %H:%M ")),
    ]
    width = sum(len(text) for _, _, text in cells)
    if screen.cursor.x + width > screen.columns:
        return
    screen.cursor.x = screen.columns - width
    for fg, bg, text in cells:
        screen.cursor.fg = as_rgb(fg)
        screen.cursor.bg = as_rgb(bg)
        screen.cursor.bold = False
        screen.draw(text)


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
    global _timer_id
    if _timer_id is None:
        _timer_id = add_timer(_redraw, 30, True)
    draw_tab_with_powerline(draw_data, screen, tab, before, max_title_length, index, is_last, extra_data)
    if is_last:
        _draw_right_status(screen)
    return screen.cursor.x
