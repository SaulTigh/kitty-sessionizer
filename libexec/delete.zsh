# summary: Delete saved kitty sessions

ks_use kitty session

ks_session_list
typeset -gi ks_count=${#ks_sessions}

if (( ks_count == 0 )); then
    ks_tracker_clear
    ks_dim "No saved sessions to delete (trackers cleared)."
    ks_pause
    return 0
fi

ks_tracker_current
typeset -g ks_current="$REPLY"

typeset -ga ks_others=()
for ks_file in "${ks_sessions[@]}"; do
    [[ "$ks_file" == "$ks_current" ]] || ks_others+=("$ks_file")
done
typeset -gi ks_others_count=${#ks_others}

# "All except current" is offered only when the current session is one of the
# saved ones and something else would still be deleted.
typeset -gi ks_keep_option=0
if (( ks_others_count > 0 && ks_others_count < ks_count )); then
    ks_keep_option=1
fi

ks_plural $ks_count session
typeset -g ks_count_label="$REPLY"
ks_plural $ks_others_count session
typeset -g ks_others_label="$REPLY"

ks_blank
ks_warn "Delete saved kitty sessions?"
ks_blank
ks_dim "  Removes saved layouts from ${KS_SESSION_DIR/#$HOME/~}."
ks_dim "  Project files are untouched."
ks_blank
if (( ks_keep_option )); then
    ks_keys "  [Enter/o] all except current ($ks_others_count)   [a] all ($ks_count)   [any other key] cancel"
else
    ks_keys "  [a] all ($ks_count)   [any other key] cancel"
fi

ks_read_key
typeset -g ks_choice="$REPLY"

if [[ "$ks_choice" == [aA] ]]; then
    ks_tracker_clear
    rm -f "${ks_sessions[@]}"
    ks_blank
    ks_ok "✔ Deleted $ks_count $ks_count_label."
    ks_pause

    # Nothing is left to return to, so open one plain tab and drop the rest.
    ks_kitty_new_tab "$HOME"
    ks_kitty_close_tabs "not state:active"
    return 0
fi

if (( ks_keep_option )) && [[ "$ks_choice" == ([oO]|$'\n'|$'\r') ]]; then
    rm -f "${ks_others[@]}"
    ks_write_lines "$KS_ACTIVE_TRACKER" "$ks_current"

    ks_kitty_title_pattern "${ks_current:t:r}"
    ks_kitty_close_tabs "not title:^${REPLY}\s::"

    ks_blank
    ks_ok "✔ Deleted $ks_others_count $ks_others_label, kept ▶ ${ks_current:t:r}."
    ks_pause
    return 0
fi

ks_dim "Cancelled, nothing deleted."
