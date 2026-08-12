# Session files and the record of which sessions are open.

ks_use common kitty

# Where the session file for a project lives. A project that carries its own
# layout wins over the generated one. Result in REPLY.
ks_session_path_for() {
    local repo="$1"
    if [[ -f "$repo/$KS_LOCAL_SESSION_NAME" ]]; then
        REPLY="$repo/$KS_LOCAL_SESSION_NAME"
    else
        REPLY="$KS_SESSION_DIR/${repo:t}$KS_SESSION_SUFFIX"
    fi
}

# Render the template for a project. Runs once, on the first switch to it.
ks_session_ensure() {
    local session="$1" repo="$2" body
    [[ -f "$session" ]] && return 0
    [[ -d "$repo" ]] || ks_die "not a directory: $repo"
    [[ -r "$KS_TEMPLATE" ]] || ks_die "missing session template: $KS_TEMPLATE"

    body="$(<"$KS_TEMPLATE")"
    body="${body//@@session-path@@/$repo}"
    body="${body//@@session@@/${session:t:r}}"

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

# Every saved session file, in the array `ks_sessions`.
ks_session_list() {
    typeset -ga ks_sessions
    ks_sessions=("$KS_SESSION_DIR"/*"$KS_SESSION_SUFFIX"(N))
}

# --- Trackers -----------------------------------------------------------------
# kitty does not report the session a tab belongs to, so the tool records the
# current session and every session it has opened.

# The session the user is in now, in REPLY. Empty when there is none.
ks_tracker_current() {
    REPLY=""
    [[ -r "$KS_CURRENT_TRACKER" ]] && REPLY="$(<"$KS_CURRENT_TRACKER")"
    return 0
}

ks_tracker_set_current() { print -r -- "$1" > "$KS_CURRENT_TRACKER" }

ks_tracker_add_active() { ks_append_unique "$KS_ACTIVE_TRACKER" "$1" }

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
