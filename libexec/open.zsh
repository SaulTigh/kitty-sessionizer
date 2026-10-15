# summary: Pick a project and switch to its kitty session

ks_use kitty session picker
ks_require_tools KS_EDITOR

# Save the layout of the session being left, so returning to it restores the
# same tabs and panes.
ks_tracker_current
ks_current_session="$REPLY"
ks_kitty_save_session "$ks_current_session"

ks_tracker_active_map
(( ${+ks_active_map[$ks_current_session]} )) || ks_current_session=""

typeset -g ks_picker_cache
ks_picker_cache="$(mktemp -d "${TMPDIR:-/tmp}/kitty-sessionizer.XXXXXX")"
trap 'rm -rf -- "$ks_picker_cache"' EXIT

# The exit status of the pipeline cannot be trusted. When the user selects a row
# before the search finishes, fzf stops reading, the row producer dies of
# SIGPIPE, and `pipefail` reports the pipeline as failed even though a row was
# chosen. An empty result is the reliable sign that nothing was selected.
typeset -g ks_selected=""
ks_selected="$(ks_picker_feed "$ks_picker_cache" | ks_picker_run "$ks_picker_cache" || true)"
[[ -n "$ks_selected" ]] || return 0

ks_selection_field "$ks_selected" $KS_FIELD_SESSION
typeset -g ks_session_file="$REPLY"
ks_selection_field "$ks_selected" $KS_FIELD_PATH
typeset -g ks_target="$REPLY"

# A plain file is not a project. Open it in a new tab and leave the session
# record alone.
if [[ -f "$ks_target" ]]; then
    ks_kitty_new_tab "${ks_target:h}" "$KS_EDITOR" "$ks_target"
    return 0
fi

[[ -d "$ks_target" && -n "$ks_session_file" ]] || ks_die "unusable selection: $ks_selected"

ks_session_enter "$ks_target"
