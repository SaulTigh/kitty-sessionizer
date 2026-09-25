# summary: Clone a git repository into a workspace directory

ks_use kitty session git gum

ks_blank
ks_gum_input "Clone URL" "" "git@host:group/repo.git"
typeset -g ks_url="$REPLY"
if [[ -z "$ks_url" ]]; then
    ks_gum_line "${KS_C_DIM}Cancelled, nothing cloned.${KS_C_RESET}"
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

ks_blank
print -rl -- "${ks_roots[@]}" | ks_gum_choose "Clone into"
typeset -g ks_parent="$REPLY"
if [[ -z "$ks_parent" ]]; then
    ks_gum_line "${KS_C_DIM}Cancelled, nothing cloned.${KS_C_RESET}"
    return 0
fi

ks_git_repo_name "$ks_url"
typeset -g ks_default_name="$REPLY"
[[ -n "$ks_default_name" ]] || ks_die "cannot read a repository name from: $ks_url"

ks_blank
ks_gum_input "Clone as" "$ks_default_name"
typeset -g ks_name="$REPLY"
if [[ -z "$ks_name" ]]; then
    ks_gum_line "${KS_C_DIM}Cancelled, nothing cloned.${KS_C_RESET}"
    return 0
fi
if [[ "$ks_name" == */* || "$ks_name" == . || "$ks_name" == .. ]]; then
    ks_die "not a folder name: $ks_name"
fi

typeset -g ks_dest="$ks_parent/$ks_name"
if [[ -e "$ks_dest" ]]; then
    ks_blank
    ks_gum_line "${KS_C_WARN}✖ Already there: ${ks_dest/#$HOME/~}${KS_C_RESET}"
    ks_gum_line "${KS_C_DIM}  Run the action again with another name.${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 1
fi

# git runs inside the `if`, because `set -e` would close the overlay on a failed
# clone before the reader sees why.
ks_blank
if ! ks_gum_spin "Cloning into ${ks_dest/#$HOME/~}…" "$KS_GIT" clone -- "$ks_url" "$ks_dest"; then
    ks_blank
    ks_gum_line "${KS_C_WARN}✖ Clone failed.${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 1
fi

ks_blank
ks_gum_line "${KS_C_OK}✔ Cloned into ${ks_dest/#$HOME/~}.${KS_C_RESET}"
ks_blank
ks_gum_confirm "Open its session?" "Open" "Exit" || return 0

# Save the layout of the session being left, so returning to it restores the
# same tabs and panes.
ks_tracker_current
ks_kitty_save_session "$REPLY"
ks_session_enter "$ks_dest"
