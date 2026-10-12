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
    local session="$1" repo="$2"
    [[ -f "$session" ]] && return 0
    [[ -d "$repo" ]] || ks_die "not a directory: $repo"
    [[ -r "$KS_TEMPLATE" ]] || ks_die "missing session template: $KS_TEMPLATE"

    ks_session_render "$repo"
    mkdir -p "${session:h}"
    print -r -- "$REPLY" > "$session"
}

# The template filled in for a project, in REPLY.
ks_session_render() {
    local repo="$1"
    while [[ "$repo" == */ ]]; do
        repo="${repo%/}"
    done
    REPLY="$(<"$KS_TEMPLATE")"
    REPLY="${REPLY//@@session-path@@/$repo}"
    REPLY="${REPLY//@@session@@/${repo:t}}"
}

# The tabs of the template for a project: the title, the directory and the
# command of each one, in `ks_default_titles`, `ks_default_cwds` and
# `ks_default_cmds`. Only the first `cd` and the first `launch` of a tab count.
# A command is kept as written, quotes and all, and split at launch time.
ks_session_default_tabs() {
    typeset -ga ks_default_titles=() ks_default_cwds=() ks_default_cmds=()
    local line
    local -a seen_cd=() seen_launch=()
    ks_session_render "$1"
    for line in "${(@f)REPLY}"; do
        case "$line" in
            'new_tab '*)
                ks_default_titles+=("${line#new_tab }")
                ks_default_cwds+=("")
                ks_default_cmds+=("")
                seen_cd+=(0)
                seen_launch+=(0)
                ;;
            'cd '*)
                (( ${#ks_default_titles} && ! seen_cd[-1] )) || continue
                ks_default_cwds[-1]="${(Q)${line#cd }}"
                seen_cd[-1]=1
                ;;
            launch|'launch '*)
                (( ${#ks_default_titles} && ! seen_launch[-1] )) || continue
                ks_default_cmds[-1]="${line#launch}"
                seen_launch[-1]=1
                ;;
        esac
    done
    return 0
}

# Open the tabs of the template that the session lacks, so a tab closed by
# accident comes back on the next switch. A tab is matched by its title. A
# missing tab opens at the end, and the focus stays where it is.
#
# Only a session made from the template has default tabs, so a project that
# carries its own layout is left alone. A session with no window open is left
# alone too, because the switch to it did not work.
ks_session_restore_defaults() {
    local session="$1" name="${1:t:r}" repo title cwd
    local -i i
    local -a args
    local -A live=()

    ks_tracker_project "$session"
    repo="$REPLY"
    [[ -n "$repo" && -d "$repo" && -r "$KS_TEMPLATE" ]] || return 0
    ks_session_path_for "$repo"
    [[ "$REPLY" == "$session" && "$session" != "$repo/$KS_LOCAL_SESSION_NAME" ]] || return 0

    ks_kitty_match_pattern "$name"
    ks_kitty_tab_titles --match-tab "session:^${REPLY}\$"
    (( ${#reply} )) || return 0
    for title in "${reply[@]}"; do
        live[$title]=1
    done

    ks_session_default_tabs "$repo"
    for (( i = 1; i <= ${#ks_default_titles}; i++ )); do
        title="${ks_default_titles[i]}"
        [[ -n "$title" ]] || continue
        (( ${+live[$title]} )) && continue
        cwd="${ks_default_cwds[i]:-$repo}"
        [[ "$cwd" == '~'* ]] && cwd="$HOME${cwd#\~}"
        args=()
        [[ -n "${ks_default_cmds[i]// }" ]] && args=("${(@Q)${(z)ks_default_cmds[i]}}")
        ks_kitty launch --type=tab --keep-focus --location=last \
            --add-to-session "$name" --tab-title "$title" --cwd "$cwd" "${args[@]}"
    done
}

# Switch kitty to a session, then bring back the default tabs it lacks.
ks_session_goto() {
    ks_kitty_goto_session "$1"
    ks_session_restore_defaults "$1"
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
    ks_tracker_set_project "$session" "$repo"
    ks_session_goto "$session"
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

# Record a move to a session. The session being left becomes the previous one,
# so every action that moves keeps `last` up to date. A move to the session the
# user is already in keeps the previous one.
ks_tracker_set_current() {
    mkdir -p "${KS_CURRENT_TRACKER:h}" "${KS_PREVIOUS_TRACKER:h}"
    ks_tracker_current
    if [[ -n "$REPLY" && "$REPLY" != "$1" ]]; then
        print -r -- "$REPLY" > "$KS_PREVIOUS_TRACKER"
    fi
    print -r -- "$1" > "$KS_CURRENT_TRACKER"
}

# The session the user was in before the current one, in REPLY. Empty when
# there is none.
ks_tracker_previous() {
    REPLY=""
    [[ -r "$KS_PREVIOUS_TRACKER" ]] && REPLY="$(<"$KS_PREVIOUS_TRACKER")"
    return 0
}

# Put a session at the top of the open list. The list holds each session once,
# so a session that is already there moves up instead of doubling.
ks_tracker_add_active() {
    local line
    local -a kept=()
    mkdir -p "${KS_ACTIVE_TRACKER:h}"
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
    ks_session_goto "$target"
}

# Go back to the session the user was in before the current one. A second press
# returns, because the move records the session it leaves as the previous one.
# Like a cycle, the move leaves the order alone. Nothing happens when the
# previous session is gone or has no window open.
ks_session_last() {
    local current target
    ks_tracker_current
    current="$REPLY"
    ks_tracker_previous
    target="$REPLY"
    [[ -n "$target" && "$target" != "$current" && -f "$target" ]] || return 0
    ks_kitty_live_session_names
    (( ${reply[(Ie)${target:t:r}]} )) || return 0
    ks_kitty_save_session "$current"
    ks_tracker_set_current "$target"
    ks_session_goto "$target"
}

# The project of each session, so a move by `prev`, `next` or `last` can render
# the template again. Each line holds the session file and the project path,
# separated by a tab. Every session the tool switches to was entered in this
# kitty first, so the record of this kitty is enough.
ks_tracker_set_project() {
    local session="$1" repo="$2" line
    local -a kept=()
    while [[ "$repo" == */ ]]; do
        repo="${repo%/}"
    done
    mkdir -p "${KS_PROJECT_TRACKER:h}"
    ks_read_lines "$KS_PROJECT_TRACKER"
    for line in "${reply[@]}"; do
        [[ "${line%%$'\t'*}" == "$session" ]] || kept+=("$line")
    done
    ks_write_lines "$KS_PROJECT_TRACKER" "$session"$'\t'"$repo" "${kept[@]}"
}

# The project of a session, in REPLY. Empty when there is none.
ks_tracker_project() {
    local line
    REPLY=""
    ks_read_lines "$KS_PROJECT_TRACKER"
    for line in "${reply[@]}"; do
        if [[ "${line%%$'\t'*}" == "$1" ]]; then
            REPLY="${line#*$'\t'}"
            return 0
        fi
    done
    return 0
}

ks_tracker_clear() { rm -f "$KS_CURRENT_TRACKER" "$KS_PREVIOUS_TRACKER" "$KS_ACTIVE_TRACKER" "$KS_PROJECT_TRACKER" }

# Open sessions as a set, in `ks_active_map`. A session counts only while its
# file exists and kitty has a window in it, so a deleted session or one whose
# tabs were closed drops the open marker.
ks_tracker_active_map() {
    typeset -gA ks_active_map=()
    local -A live=()
    local line
    ks_kitty_live_session_names
    for line in "${reply[@]}"; do
        live[$line]=1
    done
    ks_read_lines "$KS_ACTIVE_TRACKER"
    for line in "${reply[@]}"; do
        [[ -f "$line" ]] || continue
        (( ${+live[${line:t:r}]} )) && ks_active_map[$line]=1
    done
    return 0
}
