#!/usr/bin/env zsh
# Tests for the session record, the save guard and the picker order. kitten is
# faked, so no kitty has to run. The picker tests run fd and fzf. Each test runs
# in a subshell with its own state.

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
    export KS_FD=fd KS_FZF=fzf
    unset KS_SEARCH_PATH KS_FILE_SEARCH_PATH KS_EXTRA_PROJECTS KS_TEMPLATE_RULES
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

test_template_rules_keep_the_fallback_without_configuration() {
    ks_session_template_for "$PROJ"
    assert_eq "$REPLY" "$KS_TEMPLATE" template
}

test_template_rules_use_the_first_matching_directory() {
    KS_TEMPLATE_RULES="$TMP/work"$'\t'"$TMP/first"$'\n'"$PROJ"$'\t'"$TMP/second"
    ks_session_template_for "$PROJ/"
    assert_eq "$REPLY" "$TMP/first" template
    ks_session_template_for "$TMP/work-other/proj"
    assert_eq "$REPLY" "$KS_TEMPLATE" boundary
    ks_session_template_for "$TMP/other/proj"
    assert_eq "$REPLY" "$KS_TEMPLATE" fallback
}

test_template_rule_uses_a_more_specific_directory_when_listed_first() {
    KS_TEMPLATE_RULES="$PROJ/"$'\t'"$TMP/specific"$'\n'"$TMP/work"$'\t'"$TMP/general"
    ks_session_template_for "$PROJ/child"
    assert_eq "$REPLY" "$TMP/specific" template
}

test_missing_configured_template_stops_before_switching() {
    KS_TEMPLATE_RULES="$TMP/work"$'\t'"$TMP/missing"
    if ( ks_session_enter "$PROJ" ) > "$TMP/error" 2>&1; then
        fail "missing template did not stop the switch"
    fi
    [[ "$(<"$TMP/error")" == *"missing session template: $TMP/missing"* ]] || fail "missing template error"
    [[ ! -e "$P" && ! -e "$KS_CURRENT_TRACKER" ]] || fail "session state changed"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_missing_configured_template_preserves_an_existing_session() {
    print -r -- old > "$P"
    ks_tracker_set_current "$A"
    KS_TEMPLATE_RULES="$TMP/work"$'\t'"$TMP/missing"
    if ( ks_session_enter "$PROJ" ) > "$TMP/error" 2>&1; then
        fail "missing template did not stop the switch"
    fi
    assert_eq "$(<"$P")" old "saved session"
    assert_eq "$(<"$KS_CURRENT_TRACKER")" "$A" "current session"
    assert_eq "$(<"$FAKE_LOG")" "" "kitten calls"
}

test_local_session_skips_configured_template() {
    print -r -- 'new_tab own' > "$PROJ/.kitty-session"
    KS_TEMPLATE_RULES="$TMP/work"$'\t'"$TMP/missing"
    ks_session_check_template "$PROJ"
}

test_existing_session_restores_the_selected_template_without_rewriting_it() {
    print -r -- old > "$P"
    print -rl -- 'new_tab @@session@@ :: codex' 'cd @@session-path@@' 'launch codex' > "$TMP/codex"
    KS_TEMPLATE_RULES="$TMP/work"$'\t'"$TMP/codex"
    ks_tracker_set_project "$P" "$PROJ"
    ls_tabs 'proj :: nvim' 'proj :: claude' 'proj :: zsh' > "$FAKE_LS_SESSION"
    ks_session_restore_defaults "$P"
    [[ "$(<"$FAKE_LOG")" == *'proj :: codex'* ]] || fail "Codex tab was not restored"
    [[ "$(<"$FAKE_LOG")" == *$'\ncodex' ]] || fail "Codex command was not restored"
    assert_eq "$(<"$P")" old "saved session"
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

picker_paths() {
    typeset -ga reply=()
    local line
    for line in "${(@f)1}"; do
        ks_selection_field "$line" $KS_FIELD_PATH
        reply+=("${REPLY%/}")
    done
}

rank() {
    local cmd=${KS_PICKER_RANK//\{q\}/${(qq)1}}
    KS_PICKER_CACHE="$TMP/cache" sh -c "$cmd"
}

test_picker_lists_open_sessions_first_and_the_current_one_last() {
    ks_use picker
    local name out
    mkdir -p "$TMP/cache"
    print -r -- old > "$C"
    for name in a b c d; do
        mkdir -p "$TMP/work/$name"
    done
    for name in c b a; do
        ks_tracker_set_project "$KS_SESSION_DIR/work-$name.kitty-session" "$TMP/work/$name"
        ks_tracker_add_active "$KS_SESSION_DIR/work-$name.kitty-session"
    done
    ls_json work-a work-b work-c > "$FAKE_LS"
    ks_tracker_active_map
    ks_current_session="$A"
    KS_SEARCH_PATHS=("$TMP/work")

    out="$(ks_picker_feed "$TMP/cache")"
    picker_paths "$out"
    assert_eq "${reply[1,3]}" "$TMP/work/b $TMP/work/c $TMP/work/a" "open rows"
    assert_eq "${(o)reply[4,-1]}" "$TMP/work/d $TMP/work/proj" "other rows"
    [[ "${${(@f)out}[3]}" == "$KS_TAG_CURRENT "* ]] || fail "current marker: ${${(@f)out}[3]}"
    [[ -e "$TMP/cache/done" ]] || fail "no done marker"
    ks_read_lines "$TMP/cache/open"
    assert_eq "${#reply}" 3 "cached open rows"
    ks_read_lines "$TMP/cache/rest"
    assert_eq "${#reply}" 2 "cached other rows"
}

test_picker_lists_only_folders_under_a_search_path() {
    ks_use picker
    local out
    mkdir -p "$TMP/cache"
    : > "$TMP/work/note.txt"
    KS_SEARCH_PATHS=("$TMP/work")

    out="$(ks_picker_feed "$TMP/cache")"
    picker_paths "$out"
    assert_eq "${reply[*]}" "$TMP/work/proj" "rows"
}

test_picker_lists_files_and_folders_under_a_file_search_path() {
    ks_use picker
    local out
    mkdir -p "$TMP/cache" "$TMP/home/project"
    : > "$TMP/home/note.txt"
    KS_SEARCH_PATHS=("$TMP/work")
    KS_FILE_SEARCH_PATHS=("$TMP/home")

    out="$(ks_picker_feed "$TMP/cache")"
    picker_paths "$out"
    assert_eq "${(j: :)${(o)reply[@]}}" "$TMP/home/note.txt $TMP/home/project $TMP/work/proj" "rows"
}

test_environment_sets_file_search_paths_and_extra_projects() {
    export KS_FILE_SEARCH_PATH="$TMP/home:$TMP/other"
    export KS_EXTRA_PROJECTS="$TMP/one project:$TMP/two"
    unset KS_FILE_SEARCH_PATHS KS_EXTRA_PROJECT_PATHS
    _ks_loaded=()
    ks_use config

    assert_eq "${KS_FILE_SEARCH_PATHS[*]}" "$TMP/home $TMP/other" "file search paths"
    assert_eq "${KS_EXTRA_PROJECT_PATHS[*]}" "$TMP/one project $TMP/two" "extra projects"
}

test_picker_lists_extra_folders_once_without_their_children() {
    ks_use picker
    local out
    mkdir -p "$TMP/cache" "$TMP/home/config/child" "$TMP/standalone project/child"
    HOME="$TMP/home"
    KS_SEARCH_PATHS=("$TMP/home")
    KS_EXTRA_PROJECT_PATHS=("$TMP/home/config" "$TMP/standalone project" "$TMP/standalone project" "$TMP/missing")

    out="$(ks_picker_feed "$TMP/cache")"
    picker_paths "$out"
    assert_eq "${reply[*]}" "$TMP/home/config $TMP/standalone project" "rows"
}

test_picker_query_keeps_open_sessions_above_better_matches() {
    ks_use picker
    local name out
    local -a open=() rest=()
    mkdir -p "$TMP/cache"
    for name in customer-screening customerscreening.api; do
        ks_picker_row "$TMP/work/$name" "$KS_SESSION_DIR/work-$name.kitty-session"
        open+=("$REPLY")
    done
    for name in cxustomerscreening unrelated customerscreening; do
        ks_picker_row "$TMP/work/$name" "$KS_SESSION_DIR/work-$name.kitty-session"
        rest+=("$REPLY")
    done
    ks_write_lines "$TMP/cache/open" "${open[@]}"
    ks_write_lines "$TMP/cache/rest" "${rest[@]}"
    : > "$TMP/cache/done"

    out="$(rank customerscreening)"
    picker_paths "$out"
    assert_eq "${reply[*]}" "$TMP/work/customer-screening $TMP/work/customerscreening.api $TMP/work/customerscreening $TMP/work/cxustomerscreening" "ranked rows"
}

test_picker_query_with_no_match_is_not_an_error() {
    ks_use picker
    local out
    mkdir -p "$TMP/cache"
    ks_picker_row "$PROJ" ""
    ks_write_lines "$TMP/cache/open" "$REPLY"
    ks_write_lines "$TMP/cache/rest" "$REPLY"
    : > "$TMP/cache/done"
    out="$(rank asjdk)" || fail "a query with no match failed"
    assert_eq "$out" "" "ranked rows"
}

test_picker_query_reports_a_broken_fzf() {
    ks_use picker
    mkdir -p "$TMP/cache"
    : > "$TMP/cache/open"
    : > "$TMP/cache/rest"
    : > "$TMP/cache/done"
    print -rl -- '#!/bin/sh' 'exit 2' > "$TMP/broken-fzf"
    chmod +x "$TMP/broken-fzf"
    export KS_FZF="$TMP/broken-fzf"
    if rank proj > /dev/null; then
        fail "a broken fzf did not fail the query"
    fi
}

test_picker_query_waits_for_the_search_to_finish() {
    ks_use picker
    local -i pid
    mkdir -p "$TMP/cache"
    : > "$TMP/cache/open"
    : > "$TMP/cache/rest"
    rank proj > "$TMP/out" &
    pid=$!
    sleep 0.3
    kill -0 $pid 2>/dev/null || fail "the query did not wait for the search"
    ks_picker_row "$PROJ" ""
    print -r -- "$REPLY" >> "$TMP/cache/rest"
    : > "$TMP/cache/done"
    wait $pid
    picker_paths "$(<"$TMP/out")"
    assert_eq "${reply[*]}" "$PROJ" "ranked rows"
}

for t in ${(ok)functions[(I)test_*]}; do
    run "$t"
done

print -r -- ""
print -r -- "$passes passed, $failures failed"
(( failures == 0 ))
