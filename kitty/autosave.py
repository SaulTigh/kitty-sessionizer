# A kitty watcher that keeps each open session file up to date.
#
# kitty runs no hook when it is killed, so a save on exit would never run. The
# watcher saves after every change instead: a tab opens, closes or changes its
# title, or the focus moves. A burst of changes gives one save, DELAY seconds
# after the first one.
#
# Only a session the tool opened in this kitty process is saved. The tool lists
# them in its state directory, under the pid of kitty. A session kitty loaded
# from a file of its own is left alone.
#
# Load it from kitty.conf:
#
#   watcher /path/to/kitty-sessionizer/kitty/autosave.py

import os
import re
from typing import Any

from kitty.config import atomic_save
from kitty.fast_data_types import NO_CLOSE_REQUESTED, add_timer, current_application_quit_request
from kitty.session import parse_save_as_options_spec_args, seen_session_paths, session_arg_to_name

DELAY = 1.0

_pending = False


def state_dir() -> str:
    root = os.environ.get('KS_STATE_ROOT') or os.path.join(os.environ.get('XDG_RUNTIME_DIR') or '/tmp', 'kitty-sessionizer')
    return os.path.join(root, str(os.getpid()))


def tracked_sessions() -> list[str]:
    try:
        with open(os.path.join(state_dir(), 'active-sessions')) as f:
            return [line.strip() for line in f if line.strip()]
    except OSError:
        return []


# kitty splits a match expression on spaces, so a space becomes \s.
def match_for(name: str) -> str:
    return 'session:^' + re.escape(name).replace('\\ ', '\\s') + '$'


def same_file(a: str, b: str) -> bool:
    return bool(a) and bool(b) and os.path.realpath(a) == os.path.realpath(b)


def save_session(boss: Any, name: str, path: str) -> bool:
    opts, _ = parse_save_as_options_spec_args(['--use-foreground-process', '--relocatable', '--match=' + match_for(name), path])
    lines = list(boss.serialize_state_as_session(path, opts))
    if not lines:
        return False
    atomic_save('\n'.join(lines).encode(), path)
    return True


# A session is saved only while kitty runs, has a window in it, and loaded it
# from this very file. During a quit the windows close one by one, and a save
# then would keep only what is left.
def save_all(boss: Any) -> list[str]:
    if current_application_quit_request() != NO_CLOSE_REQUESTED:
        return []
    loaded = set(boss.all_loaded_session_names)
    saved = []
    for path in tracked_sessions():
        name = session_arg_to_name(path)
        if not name or name not in loaded or not os.path.isfile(path):
            continue
        if not same_file(seen_session_paths.get(name, ''), path):
            continue
        if save_session(boss, name, path):
            saved.append(path)
    return saved


def schedule(boss: Any) -> None:
    global _pending
    if _pending:
        return
    _pending = True

    def fire(timer_id: int | None) -> None:
        global _pending
        _pending = False
        save_all(boss)

    add_timer(fire, DELAY, False)


def on_tab_bar_dirty(boss: Any, window: Any, data: dict[str, Any]) -> None:
    schedule(boss)


def on_focus_change(boss: Any, window: Any, data: dict[str, Any]) -> None:
    schedule(boss)
