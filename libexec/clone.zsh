# summary: Clone a git repository into a workspace directory

ks_use kitty session picker git

ks_blank
ks_read_line "Clone URL >> "
typeset -g ks_url="$REPLY"
if [[ -z "$ks_url" ]]; then
    ks_dim "Cancelled, nothing cloned."
    return 0
fi

# The search paths are the directories the picker already knows about, so a
# clone lands where the picker will find it again. A path that has gone is
# skipped, the same as in discovery.
typeset -ga ks_roots=()
for ks_root in "${KS_SEARCH_PATHS[@]}"; do
    if [[ -d "$ks_root" ]]; then
        ks_roots+=("$ks_root")
    fi
done
(( ${#ks_roots} )) || ks_die "no search path exists to clone into"

typeset -g ks_parent=""
ks_parent="$(print -rl -- "${ks_roots[@]}" | ks_picker_run "$KS_FZF_DIR_OPTS" || true)"
if [[ -z "$ks_parent" ]]; then
    ks_dim "Cancelled, nothing cloned."
    return 0
fi

ks_git_repo_name "$ks_url"
typeset -g ks_default_name="$REPLY"
[[ -n "$ks_default_name" ]] || ks_die "cannot read a repository name from: $ks_url"

ks_blank
ks_read_line "Clone as >> " "$ks_default_name"
typeset -g ks_name="$REPLY"
if [[ -z "$ks_name" ]]; then
    ks_dim "Cancelled, nothing cloned."
    return 0
fi
if [[ "$ks_name" == */* || "$ks_name" == . || "$ks_name" == .. ]]; then
    ks_die "not a folder name: $ks_name"
fi

typeset -g ks_dest="$ks_parent/$ks_name"
if [[ -e "$ks_dest" ]]; then
    ks_blank
    ks_warn "✖ Already there: ${ks_dest/#$HOME/~}"
    ks_dim "  Run the action again with another name."
    ks_pause
    return 1
fi

# git runs inside the `if`, because `set -e` would close the overlay on a failed
# clone before the reader sees why.
ks_blank
if ! ks_git_clone "$ks_url" "$ks_dest"; then
    ks_blank
    ks_warn "✖ Clone failed."
    ks_pause
    return 1
fi

ks_blank
ks_ok "✔ Cloned into ${ks_dest/#$HOME/~}."
ks_blank
ks_keys "  [Enter] open its session   [any other key] close"

ks_read_key
[[ "$REPLY" == ($'\n'|$'\r') ]] || return 0

# Save the layout of the session being left, so returning to it restores the
# same tabs and panes.
ks_tracker_current
ks_kitty_save_session "$REPLY"
ks_session_enter "$ks_dest"
