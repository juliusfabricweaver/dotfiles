# Gruvbox rounded-pill tab bar with date/time pills on the right
from datetime import datetime

from kitty.boss import get_boss
from kitty.fast_data_types import Screen, add_timer
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb, draw_title
from kitty.utils import color_as_int

LEFT_CAP = ""
RIGHT_CAP = ""
ICON_DATE = ""
ICON_TIME = ""

FG_DARK = 0x282828
FG_LIGHT = 0xA89984
BG_DATE = 0x3C3836
BG_TIME = 0xFABD2F

_timer_id = None


def _redraw(_timer_id):
    for tm in get_boss().all_tab_managers:
        tm.mark_tab_bar_dirty()


def _draw_pill(screen: Screen, bar_bg: int, fg: int, bg: int, text: str, bold: bool = False) -> None:
    screen.cursor.bold = False
    screen.cursor.fg = bg
    screen.cursor.bg = bar_bg
    screen.draw(LEFT_CAP)
    screen.cursor.fg = fg
    screen.cursor.bg = bg
    screen.cursor.bold = bold
    screen.draw(text)
    screen.cursor.bold = False
    screen.cursor.fg = bg
    screen.cursor.bg = bar_bg
    screen.draw(RIGHT_CAP)


def _draw_right_status(screen: Screen, bar_bg: int) -> None:
    now = datetime.now()
    pills = [
        (as_rgb(FG_LIGHT), as_rgb(BG_DATE), f"{ICON_DATE} {now:%d %b}"),
        (as_rgb(FG_DARK), as_rgb(BG_TIME), f"{ICON_TIME} {now:%H:%M}"),
    ]
    # each pill is two caps plus its text, with one space between pills and one at the edge
    width = sum(len(text) + 2 for _, _, text in pills) + len(pills)
    if screen.cursor.x + width > screen.columns:
        return
    screen.cursor.bg = bar_bg
    screen.draw(" " * (screen.columns - width - screen.cursor.x))
    for fg, bg, text in pills:
        _draw_pill(screen, bar_bg, fg, bg, text)
        screen.cursor.bg = bar_bg
        screen.draw(" ")


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

    # kitty sets the cursor colours to the active/inactive tab colours from kitty.conf
    tab_fg, tab_bg = screen.cursor.fg, screen.cursor.bg
    bar_bg = as_rgb(color_as_int(draw_data.default_bg))

    if index == 1:
        screen.cursor.bg = bar_bg
        screen.draw(" ")

    screen.cursor.bold = False
    screen.cursor.fg = tab_bg
    screen.cursor.bg = bar_bg
    screen.draw(LEFT_CAP)
    screen.cursor.fg = tab_fg
    screen.cursor.bg = tab_bg
    screen.cursor.bold = tab.is_active
    draw_title(draw_data, screen, tab, index, max_title_length)
    screen.cursor.bold = False
    screen.cursor.fg = tab_bg
    screen.cursor.bg = bar_bg
    screen.draw(RIGHT_CAP)
    end = screen.cursor.x
    screen.draw(" ")

    if is_last:
        _draw_right_status(screen, bar_bg)
    return end
