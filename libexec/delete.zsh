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

# A row marks a session the way the project picker does. The first row stands
# for every session at once. The map leads from a row back to its file. gum
# gives a pick back without its leading spaces, so the key is the row without
# them too.
typeset -g ks_all_row="All ($ks_count)"
typeset -ga ks_rows=("$ks_all_row")
typeset -gA ks_row_file=()
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
done

ks_blank
# gum lists only x in its own help line, so the keys go above the list.
ks_gum_line "${KS_C_DIM}Controls: [x/Tab] mark, [Ctrl-A] mark all, [Enter] submit, [Esc] cancel${KS_C_RESET}"

# Enter alone submits nothing in a multi-select: gum takes the cursor row only
# when the limit is one. Say so, because the cursor highlight looks like a mark.
print -rl -- "${ks_rows[@]}" | ks_gum_choose_many "Delete sessions"
if (( ! ${#reply} )); then
    ks_gum_line "${KS_C_DIM}Nothing marked, nothing deleted.${KS_C_RESET}"
    ks_gum_line "${KS_C_DIM}  Mark a row with x or Tab, then press Enter.${KS_C_RESET}"
    ks_blank
    ks_pause "${ks_gum_indent}Press any key to close…"
    return 0
fi

typeset -ga ks_targets=()
if (( ${reply[(Ie)$ks_all_row]} )); then
    ks_targets=("${ks_sessions[@]}")
else
    for ks_row in "${reply[@]}"; do
        ks_key="${ks_row%%[! ]*}"
        ks_key="${ks_row#$ks_key}"
        (( ${+ks_row_file[$ks_key]} )) || ks_die "unknown row: $ks_row"
        ks_targets+=("${ks_row_file[$ks_key]}")
    done
fi
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
ks_blank
ks_pause "${ks_gum_indent}Press any key to close…"

# The tabs go after the pause, because the overlay sits in one of them.
#
# When the current session goes, nothing is left to return to, so one plain
# tab opens and every other tab closes. Otherwise only the tabs of the deleted
# sessions close. Match on the session, not on the title: kitty names a
# session after its file, so the match is exact.
if (( ks_current_gone )); then
    ks_kitty_new_tab "$HOME"
    ks_kitty_close_tabs "not state:active"
    return 0
fi
for ks_file in "${ks_targets[@]}"; do
    (( ${+ks_active_map[$ks_file]} )) || continue
    ks_kitty_match_pattern "${ks_file:t:r}"
    ks_kitty_close_tabs "session:^${REPLY}\$"
done
