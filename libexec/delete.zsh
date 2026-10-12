# summary: Delete saved kitty sessions

ks_use kitty session gum

ks_session_list
typeset -gi ks_count=${#ks_sessions}

if (( ks_count == 0 )); then
    ks_tracker_clear
    ks_blank
    ks_gum_line "${KS_C_DIM}No saved sessions to delete (trackers cleared).${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 0
fi

ks_tracker_current
typeset -g ks_current="$REPLY"
ks_tracker_active_map
(( ${+ks_active_map[$ks_current]} )) || ks_current=""

# A row marks a session the way the project picker does. The map leads from a
# row back to its file. gum gives a pick back without its leading spaces, so
# the key is the row without them too.
typeset -ga ks_rows=()
typeset -gA ks_row_file=()
typeset -gA ks_file_row=()
for ks_file in "${ks_sessions[@]}"; do
    ks_tag="$KS_TAG_NONE"
    if [[ "$ks_file" == "$ks_current" ]]; then
        ks_tag="$KS_TAG_CURRENT"
    elif (( ${+ks_active_map[$ks_file]} )); then
        ks_tag="$KS_TAG_ACTIVE"
    fi
    ks_row="$ks_tag ${ks_file:t:r}"
    ks_rows+=("$ks_row")
    ks_key="${ks_row%%[! ]*}"
    ks_key="${ks_row#$ks_key}"
    ks_row_file[$ks_key]="$ks_file"
    ks_file_row[$ks_file]="$ks_row"
done

ks_blank
# Enter alone submits nothing in a multi-select: gum takes the cursor row only
# when the limit is one. Say so, because the cursor highlight looks like a mark.
print -rl -- "${ks_rows[@]}" | ks_gum_choose_many "Delete sessions"
if (( ! ${#reply} )); then
    ks_gum_line "${KS_C_WARN}✖ Nothing marked, nothing deleted.${KS_C_RESET}"
    ks_gum_line "${KS_C_DIM}  Mark a row with x or Tab, then press Enter.${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 0
fi

typeset -ga ks_targets=()
for ks_row in "${reply[@]}"; do
    ks_key="${ks_row%%[! ]*}"
    ks_key="${ks_row#$ks_key}"
    (( ${+ks_row_file[$ks_key]} )) || ks_die "unknown row: $ks_row"
    ks_targets+=("${ks_row_file[$ks_key]}")
done

# The picks, printed back as they stood in the list, so the marks line up.
ks_gum_line "${KS_C_LABEL}Delete sessions${KS_C_RESET}"
for ks_file in "${ks_targets[@]}"; do
    ks_gum_line "  ${ks_file_row[$ks_file]}"
done
typeset -gi ks_n=${#ks_targets}
ks_plural $ks_n session
typeset -g ks_label="$REPLY"

ks_blank
if ! ks_gum_confirm "Delete $ks_n $ks_label?" "Delete" "Cancel"; then
    ks_gum_line "${KS_C_DIM}Cancelled, nothing deleted.${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 0
fi

typeset -gA ks_target_set=()
for ks_file in "${ks_targets[@]}"; do
    ks_target_set[$ks_file]=1
done
typeset -gi ks_current_gone=0
[[ -n "$ks_current" ]] && (( ${+ks_target_set[$ks_current]} )) && ks_current_gone=1

rm -f -- "${ks_targets[@]}"

# The trackers drop what was deleted. Nothing is left when every session went.
if (( ks_n == ks_count )); then
    ks_tracker_clear
else
    ks_read_lines "$KS_ACTIVE_TRACKER"
    typeset -ga ks_kept=()
    for ks_line in "${reply[@]}"; do
        (( ${+ks_target_set[$ks_line]} )) || ks_kept+=("$ks_line")
    done
    ks_write_lines "$KS_ACTIVE_TRACKER" "${ks_kept[@]}"
    (( ks_current_gone )) && rm -f "$KS_CURRENT_TRACKER"
fi

ks_blank
ks_gum_line "${KS_C_OK}✔ Deleted $ks_n $ks_label.${KS_C_RESET}"
for ks_file in "${ks_targets[@]}"; do
    ks_gum_line "${KS_C_DIM}  ✖ ${ks_file:t:r}${KS_C_RESET}"
done

# When the current session goes, the user lands in one of the sessions that
# stayed open. The prompt ends only with a pick: the tab the overlay sits in is
# about to close, so there is nothing to cancel back to. A list of one is taken
# without a prompt.
typeset -g ks_next=""
if (( ks_current_gone )); then
    typeset -ga ks_open_rows=()
    typeset -gA ks_open_row_file=()
    for ks_file in "${ks_sessions[@]}"; do
        (( ${+ks_active_map[$ks_file]} )) || continue
        (( ${+ks_target_set[$ks_file]} )) && continue
        ks_open_rows+=("${ks_file:t:r}")
        ks_open_row_file[${ks_file:t:r}]="$ks_file"
    done
    if (( ${#ks_open_rows} )); then
        ks_blank
        while [[ -z "$ks_next" ]]; do
            print -rl -- "${ks_open_rows[@]}" | ks_gum_choose "Switch to session"
            [[ -n "$REPLY" ]] && ks_next="${ks_open_row_file[$REPLY]}"
        done
    fi
fi

ks_blank
ks_pause "${ks_gum_indent}Press any key to close…"

# The tabs go after the pause, because the overlay sits in one of them.
#
# When the current session goes and no open session is left, one plain tab
# opens and every other tab closes. Otherwise the picked session takes focus
# first, and only the tabs of the deleted sessions close. Match on the session,
# not on the title: kitty names a session after its file, so the match is
# exact. The current session goes last, because its tab holds the overlay.
if (( ks_current_gone )); then
    if [[ -z "$ks_next" ]]; then
        ks_kitty_new_tab "$HOME"
        ks_kitty_close_tabs "not state:active"
        return 0
    fi
    ks_tracker_set_current "$ks_next"
    ks_session_goto "$ks_next"
fi
for ks_file in "${ks_targets[@]}"; do
    [[ "$ks_file" == "$ks_current" ]] && continue
    (( ${+ks_active_map[$ks_file]} )) || continue
    ks_kitty_match_pattern "${ks_file:t:r}"
    ks_kitty_close_tabs "session:^${REPLY}\$"
done
if (( ks_current_gone )); then
    ks_kitty_match_pattern "${ks_current:t:r}"
    ks_kitty_close_tabs "session:^${REPLY}\$"
fi
