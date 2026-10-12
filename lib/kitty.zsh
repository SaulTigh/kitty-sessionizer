# Thin wrappers over `kitten @`.
#
# kitty is not always reachable: remote control can be off, or the window that
# owned the session can be gone. A failed call must never stop an action, so
# every call here drops its error.

ks_use config
ks_require_tools KS_KITTEN

ks_kitty() { "$KS_KITTEN" @ "$@" 2>/dev/null || true }

# Write the live layout back to the session file before leaving it, so returning
# to the session restores the same tabs and panes.
#
# `--match=session:.` takes the windows of the session kitty is in, whatever
# file the tool names. So the save runs only when the two agree. Otherwise the
# windows of another session, or of no session, would overwrite the file.
ks_kitty_save_session() {
    [[ -f "${1:-}" ]] || return 0
    ks_kitty_active_session_name
    [[ -n "$REPLY" && "$REPLY" == "${1:t:r}" ]] || return 0
    ks_kitty action save_as_session \
        --use-foreground-process --relocatable --match=session:. --save-only "$1"
}

ks_kitty_goto_session() { ks_kitty action goto_session "$1" }

# The names of the sessions that have a window open, in `reply`. kitty names a
# session after its file, so a name matches `${file:t:r}`. The JSON is read by
# line, because `ls` prints one field per line and a JSON parser would be one
# more tool to require. Arguments go to `ls`, to narrow what it lists.
ks_kitty_session_names() {
    typeset -ga reply=()
    local out line name
    local -A seen=()
    out="$(ks_kitty ls "$@")"
    for line in "${(@f)out}"; do
        [[ "$line" == *'"session_name": "'* ]] || continue
        name="${line#*\"session_name\": \"}"
        name="${name%\"*}"
        [[ -n "$name" ]] || continue
        (( ${+seen[$name]} )) && continue
        seen[$name]=1
        reply+=("$name")
    done
    return 0
}

ks_kitty_live_session_names() { ks_kitty_session_names }

# The titles of the tabs that `ls` lists, in `reply`. A tab title sits at the
# fourth level of the JSON, eight spaces in. A window title sits deeper, so the
# indent tells the two apart. Arguments go to `ls`.
ks_kitty_tab_titles() {
    typeset -ga reply=()
    local out line title
    out="$(ks_kitty ls "$@")"
    for line in "${(@f)out}"; do
        [[ "$line" == '        "title": "'* ]] || continue
        title="${line#*\"title\": \"}"
        title="${title%\"*}"
        reply+=("$title")
    done
    return 0
}

# The session of the focused tab, in REPLY. Empty when the tab has no session.
# An overlay such as the picker belongs to no session, so the first name in the
# tab is the one.
ks_kitty_active_session_name() {
    ks_kitty_session_names --match-tab state:focused
    REPLY="${reply[1]:-}"
}

ks_kitty_new_tab() {
    local cwd="$1"
    shift
    ks_kitty launch --type=tab --cwd "$cwd" "$@"
}

ks_kitty_close_tabs() {
    [[ -n "${1:-}" ]] || return 0
    ks_kitty close-tab --match "$1"
}

# kitty reads a match value as a regular expression, so a name with a dot or a
# bracket has to be escaped first. A space becomes \s because kitty splits a
# match expression on spaces to read its boolean operators.
ks_kitty_match_pattern() {
    local out="$1" ch
    for ch in '\' '[' ']' '^' '$' '.' '|' '*' '+' '?' '(' ')' '{' '}'; do
        out="${out//"$ch"/\\$ch}"
    done
    REPLY="${out// /\\s}"
}
