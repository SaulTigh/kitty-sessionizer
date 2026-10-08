# Session files and the record of which sessions are open.

ks_use common kitty

# Where the session file for a project lives. A project that carries its own
# layout wins over the generated one. Result in REPLY.
#
# The name holds the directory the project sits in as well as the project,
# because every generated file shares one flat directory. The name alone is not
# unique: ~/workspace/personal/roboboba and ~/workspace/backups/roboboba are two
# projects, and with the name alone they would share one session and one tab
# title. The picker shows a project the same way, as `personal/roboboba`.
ks_session_path_for() {
    local repo="$1"
    if [[ -f "$repo/$KS_LOCAL_SESSION_NAME" ]]; then
        REPLY="$repo/$KS_LOCAL_SESSION_NAME"
        return 0
    fi
    # `fd` writes a directory with a trailing slash and the picker passes that
    # straight in, so the slash goes before the parts are read off the end.
    while [[ "$repo" == */ ]]; do
        repo="${repo%/}"
    done
    REPLY="$KS_SESSION_DIR/${repo:h:t}$KS_SESSION_NAME_SEP${repo:t}$KS_SESSION_SUFFIX"
}

# Render the template for a project. Runs once, on the first switch to it.
#
# @@session@@ is the project alone, not the name of the session file. The
# template writes it into the tab title, and a title reads better without the
# directory in front of it. kitty keeps the sessions apart on its own: it names
# a session after its file, so a match on `session:` still finds one session.
ks_session_ensure() {
    local session="$1" repo="$2" body
    [[ -f "$session" ]] && return 0
    [[ -d "$repo" ]] || ks_die "not a directory: $repo"
    [[ -r "$KS_TEMPLATE" ]] || ks_die "missing session template: $KS_TEMPLATE"

    while [[ "$repo" == */ ]]; do
        repo="${repo%/}"
    done

    body="$(<"$KS_TEMPLATE")"
    body="${body//@@session-path@@/$repo}"
    body="${body//@@session@@/${repo:t}}"

    mkdir -p "${session:h}"
    print -r -- "$body" > "$session"
}

# Switch to the session of a project, and record the move. Every action that
# enters a project goes through here, so the trackers never miss one.
#
# The caller saves the layout of the session it leaves, because each action does
# that at a different moment.
ks_session_enter() {
    local repo="$1" session
    ks_session_path_for "$repo"
    session="$REPLY"
    ks_session_ensure "$session" "$repo"
    ks_tracker_set_current "$session"
    ks_tracker_add_active "$session"
    ks_kitty_goto_session "$session"
}

# Every saved session file, in the array `ks_sessions`. A project under a
# dot directory, such as ~/.config/nvim, gives a file that starts with a dot,
# so the glob has to take dotfiles too.
ks_session_list() {
    typeset -ga ks_sessions
    ks_sessions=("$KS_SESSION_DIR"/*"$KS_SESSION_SUFFIX"(ND))
}

# --- Trackers -----------------------------------------------------------------
# kitty reports the session of a window, but not the order the sessions were
# used in, so the tool records the current session and every session it has
# opened, newest first.

# The session the user is in now, in REPLY. Empty when there is none.
ks_tracker_current() {
    REPLY=""
    [[ -r "$KS_CURRENT_TRACKER" ]] && REPLY="$(<"$KS_CURRENT_TRACKER")"
    return 0
}

ks_tracker_set_current() { print -r -- "$1" > "$KS_CURRENT_TRACKER" }

# Put a session at the top of the open list. The list holds each session once,
# so a session that is already there moves up instead of doubling.
ks_tracker_add_active() {
    local line
    local -a kept=()
    ks_read_lines "$KS_ACTIVE_TRACKER"
    for line in "${reply[@]}"; do
        [[ "$line" == "$1" ]] || kept+=("$line")
    done
    ks_write_lines "$KS_ACTIVE_TRACKER" "$1" "${kept[@]}"
}

# The session `step` places away from `current` in the open list, in REPLY. A
# step of 1 goes to an older session, -1 to a newer one, and both wrap. Only a
# session with a window open counts, so a session closed by hand drops out of
# the cycle instead of reopening. Empty when there is nothing to move to.
#
# When `current` is not in the list, 1 gives the newest session and -1 the
# oldest, the same two the steps would reach from just past either end.
ks_tracker_cycle_target() {
    local -i step=$1
    local current="$2" line
    local -a open=()
    local -A live=()
    REPLY=""

    ks_kitty_live_session_names
    for line in "${reply[@]}"; do
        live[$line]=1
    done

    ks_read_lines "$KS_ACTIVE_TRACKER"
    for line in "${reply[@]}"; do
        [[ -f "$line" ]] || continue
        (( ${+live[${line:t:r}]} )) || continue
        open+=("$line")
    done
    local -i n=${#open}
    (( n >= 2 )) || return 0

    local -i i=${open[(Ie)$current]}
    if (( i == 0 )); then
        (( step > 0 )) && i=0 || i=1
    fi
    REPLY="${open[(i - 1 + step + n) % n + 1]}"
    return 0
}

# Move through the open sessions in the order they were used. The move records
# the new current session but leaves the order alone. A move that counted as a
# use would put the target on top, and the second press would come straight
# back instead of going on.
ks_session_cycle() {
    local current target
    ks_tracker_current
    current="$REPLY"
    ks_tracker_cycle_target "$1" "$current"
    target="$REPLY"
    [[ -n "$target" ]] || return 0
    ks_kitty_save_session "$current"
    ks_tracker_set_current "$target"
    ks_kitty_goto_session "$target"
}

ks_tracker_clear() { rm -f "$KS_CURRENT_TRACKER" "$KS_ACTIVE_TRACKER" }

# Open sessions as a set, in `ks_active_map`. A record whose file has gone is
# dropped, so a deleted session stops showing the open marker.
ks_tracker_active_map() {
    typeset -gA ks_active_map=()
    ks_read_lines "$KS_ACTIVE_TRACKER"
    local line
    for line in "${reply[@]}"; do
        [[ -f "$line" ]] && ks_active_map[$line]=1
    done
    return 0
}
