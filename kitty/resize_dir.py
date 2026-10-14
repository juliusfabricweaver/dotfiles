# Directional pane resize for kitty's "splits" layout, mimicking tmux's
# resize-pane -L/-R/-U/-D: move the pane's edge in the given direction.
#
# Usage in kitty.conf:  map <keys> kitten resize_dir.py <left|right|up|down> [cells]
#
# For "right": the divider on the pane's right edge moves right (pane grows).
# If the pane has no divider on that side (it touches the screen edge), the
# divider on its left edge moves right instead (pane shrinks), like tmux.

from typing import List

STEP = 5


def main(args: List[str]) -> str:
    return ''


def _ancestors(root, pair):
    """Yield (pair, which) from the window's own pair up to the root.
    which == 1 when the previous node is pair.one, 2 when it is pair.two."""
    child = None
    p = pair
    while p is not None:
        if child is not None:
            yield p, (1 if p.one is child else 2)
        child = p
        p = p.parent(root)


def handle_result(args: List[str], answer: str, target_window_id: int, boss) -> None:
    direction = args[1] if len(args) > 1 else 'right'
    cells = int(args[2]) if len(args) > 2 else STEP
    tab = boss.active_tab
    if tab is None:
        return
    layout = tab.current_layout
    if getattr(layout, 'name', '') != 'splits':
        # fall back to kitty's relative resize in other layouts
        quality = {'left': 'narrower', 'right': 'wider', 'up': 'shorter', 'down': 'taller'}[direction]
        tab.resize_window(quality, cells)
        return

    w = tab.active_window
    if w is None:
        return
    grp = tab.windows.group_for_window(w.id)
    if grp is None:
        return
    root = layout.pairs_root
    pair = root.pair_for_window(grp.id)
    if pair is None:
        return

    is_horizontal = direction in ('left', 'right')
    # +bias grows pair.one, i.e. moves the divider right/down
    sign = 1 if direction in ('right', 'down') else -1
    # the divider adjacent on the requested side: window is in .one for
    # right/down (divider after it) and in .two for left/up (divider before it)
    want_which = 1 if direction in ('right', 'down') else 2

    candidates = [(p, which) for p, which in [(pair, 1 if pair.one == grp.id else 2)] + list(_ancestors(root, pair))
                  if p.horizontal == is_horizontal and not p.is_redundant]
    if not candidates:
        return
    adjacent = [c for c in candidates if c[1] == want_which]
    target_pair, _ = (adjacent or candidates)[0]

    inc = layout.bias_increment_for_cell(tab.windows, is_horizontal) * cells * sign
    new_bias = max(0.0, min(target_pair.bias + inc, 1.0))
    if new_bias != target_pair.bias:
        target_pair.bias = new_bias
        tab.relayout()


handle_result.no_ui = True  # type: ignore
