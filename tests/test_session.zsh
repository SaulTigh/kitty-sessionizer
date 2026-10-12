#!/usr/bin/env zsh
# Tests for the session record and the save guard. kitten is faked, so no kitty
# has to run. Each test runs in a subshell with its own state.

set -euo pipefail

typeset -g KS_ROOT="${0:A:h:h}"
typeset -g KS_LIB="$KS_ROOT/lib"
typeset -gi failures=0 passes=0

fail() { print -ru2 -- "  FAIL: $*"; exit 1 }

assert_eq() {
    [[ "$1" == "$2" ]] || fail "${3:-value}: expected [$2], got [$1]"
}

# A line of `kitten @ ls` per session name. An empty name stands for an overlay.
ls_json() {
    local name
    for name in "$@"; do
        print -r -- "            \"session_name\": \"$name\","
    done
}

# A line of `kitten @ ls` per tab title.
ls_tabs() {
    local title
    for title in "$@"; do
        print -r -- "        \"title\": \"$title\","
    done
}

setup() {
    TMP="$(mktemp -d)"
    export FAKE_LOG="$TMP/log" FAKE_LS="$TMP/ls" FAKE_LS_FOCUSED="$TMP/ls-focused" FAKE_LS_SESSION="$TMP/ls-session"
    : > "$FAKE_LOG"
    export KS_KITTEN="$KS_ROOT/tests/fake-kitten"
    export KS_STATE_ROOT="$TMP/state"
    export KS_SESSION_DIR="$TMP/sessions"
    export KITTY_PID=4242
    mkdir -p "$KS_SESSION_DIR"
    A="$KS_SESSION_DIR/work-a.kitty-session"
    B="$KS_SESSION_DIR/work-b.kitty-session"
    C="$KS_SESSION_DIR/work-c.kitty-session"
    print -r -- old > "$A"
    print -r -- old > "$B"
    PROJ="$TMP/work/proj"
    mkdir -p "$PROJ"
    export KS_TEMPLATE="$TMP/template"
    cat > "$KS_TEMPLATE" <<'TPL'
new_tab @@session@@ :: nvim
cd @@session-path@@
launch --title "@@session@@ :: nvim" zsh -i -c "nvim;zsh"

new_tab @@session@@ :: zsh
cd @@session-path@@
launch zsh -i
focus_tab 0
TPL
    P="$KS_SESSION_DIR/work-proj.kitty-session"
    source "$KS_LIB/bootstrap.zsh"
    ks_use common session
}

run() {
    local name="$1"
    if ( setup; trap 'rm -rf "$TMP"' EXIT; "$name" ); then
        passes+=1
        print -r -- "ok    $name"
    else
        failures+=1
        print -r -- "FAIL  $name"
    fi
}

test_state_dir_is_keyed_to_the_kitty_pid() {
    assert_eq "$KS_ACTIVE_TRACKER" "$TMP/state/4242/active-sessions" tracker
    ks_tracker_set_current "$A"
    [[ -f "$TMP/state/4242/current-session" ]] || fail "current tracker not written"
}

test_a_restarted_kitty_starts_with_an_empty_record() {
    ks_tracker_add_active "$A"
    ks_tracker_set_current "$A"
    (
        KITTY_PID=5151
        unset KS_STATE_DIR KS_CURRENT_TRACKER KS_PREVIOUS_TRACKER KS_ACTIVE_TRACKER
        _ks_loaded=()
        ks_use config session
        ls_json work-a > "$FAKE_LS"
        ks_tracker_current
        assert_eq "$REPLY" "" current
        ks_tracker_active_map
        assert_eq "${#ks_active_map}" 0 "open sessions"
    )
}

test_open_marker_needs_a_live_window() {
    ks_tracker_add_active "$C"
    ks_tracker_add_active "$B"
    ks_tracker_add_active "$A"
    ls_json work-a "" work-c > "$FAKE_LS"
    ks_tracker_active_map
    assert_eq "${(k)ks_active_map}" "$A" "open sessions"
}

test_no_open_marker_when_kitty_is_unreachable() {
    ks_tracker_add_active "$A"
    ks_tracker_active_map
    assert_eq "${#ks_active_map}" 0 "open sessions"
}

test_save_runs_when_kitty_is_in_that_session() {
    ls_json "" work-a > "$FAKE_LS_FOCUSED"
    ks_kitty_save_session "$A"
    local expected
    expected="$(print -rl -- action save_as_session --use-foreground-process --relocatable \
        --match=session:. --save-only "$A" "")"
    assert_eq "$(<"$FAKE_LOG")" "$expected" "kitten calls"
}

test_save_skips_when_kitty_is_in_another_session() {
    ls_json work-b > "$FAKE_LS_FOCUSED"
    ks_kitty_save_session "$A"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_save_skips_a_tab_with_no_session() {
    ls_json "" "" > "$FAKE_LS_FOCUSED"
    ks_kitty_save_session "$A"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_save_skips_a_missing_file() {
    ls_json work-c > "$FAKE_LS_FOCUSED"
    ks_kitty_save_session "$C"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_switch_reopens_a_missing_default_tab() {
    ks_tracker_set_project "$P" "$PROJ/"
    ls_tabs "proj :: nvim" "extra" > "$FAKE_LS_SESSION"
    ks_session_goto "$P"
    local expected
    expected="$(print -rl -- action goto_session "$P" "" \
        launch --type=tab --keep-focus --location=last --add-to-session work-proj \
        --tab-title "proj :: zsh" --cwd "$PROJ" zsh -i "")"
    assert_eq "$(<"$FAKE_LOG")" "$expected" "kitten calls"
}

test_switch_reopens_a_command_with_its_quotes_intact() {
    ks_tracker_set_project "$P" "$PROJ"
    ls_tabs "proj :: zsh" > "$FAKE_LS_SESSION"
    ks_session_restore_defaults "$P"
    local expected
    expected="$(print -rl -- launch --type=tab --keep-focus --location=last --add-to-session work-proj \
        --tab-title "proj :: nvim" --cwd "$PROJ" --title "proj :: nvim" zsh -i -c "nvim;zsh" "")"
    assert_eq "$(<"$FAKE_LOG")" "$expected" "kitten calls"
}

test_switch_opens_nothing_when_every_default_tab_is_there() {
    ks_tracker_set_project "$P" "$PROJ"
    ls_tabs "proj :: zsh" "proj :: nvim" > "$FAKE_LS_SESSION"
    ks_session_restore_defaults "$P"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_switch_opens_nothing_when_the_session_has_no_tab() {
    ks_tracker_set_project "$P" "$PROJ"
    ks_session_restore_defaults "$P"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_switch_opens_nothing_for_an_unknown_project() {
    ls_tabs "extra" > "$FAKE_LS_SESSION"
    ks_session_restore_defaults "$P"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_switch_leaves_a_project_layout_alone() {
    print -r -- "new_tab own" > "$PROJ/.kitty-session"
    ks_tracker_set_project "$PROJ/.kitty-session" "$PROJ"
    ls_tabs "own" > "$FAKE_LS_SESSION"
    ks_session_restore_defaults "$PROJ/.kitty-session"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_project_record_keeps_one_line_per_session() {
    ks_tracker_set_project "$P" "$TMP/old"
    ks_tracker_set_project "$A" "$TMP/a"
    ks_tracker_set_project "$P" "$PROJ/"
    ks_tracker_project "$P"
    assert_eq "$REPLY" "$PROJ" project
    ks_read_lines "$KS_PROJECT_TRACKER"
    assert_eq "${#reply}" 2 lines
}

test_enter_records_the_project_and_restores_tabs() {
    ls_tabs "proj :: nvim" > "$FAKE_LS_SESSION"
    ks_session_enter "$PROJ/"
    ks_tracker_project "$P"
    assert_eq "$REPLY" "$PROJ" project
    [[ -f "$P" ]] || fail "session file not rendered"
    [[ "$(<"$FAKE_LOG")" == *"--tab-title"$'\n'"proj :: zsh"* ]] || fail "zsh tab not reopened: $(<"$FAKE_LOG")"
}

for t in ${(ok)functions[(I)test_*]}; do
    run "$t"
done

print -r -- ""
print -r -- "$passes passed, $failures failed"
(( failures == 0 ))
