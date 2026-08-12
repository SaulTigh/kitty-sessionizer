# The fzf picker: the row format, the run, and the read-back of a selection.

ks_use common discovery session
ks_require_tools KS_FZF

# A row holds four tab-separated fields:
#   1  marker and project name, padded  (searched and shown)
#   2  the group the project sits in    (shown only)
#   3  the session file for the project (data)
#   4  the path that was found          (data)
typeset -gr KS_FIELD_SESSION=3
typeset -gr KS_FIELD_PATH=4

# The marker state. An action fills these in before it builds the rows; the
# defaults keep the picker usable when it does not.
typeset -g ks_current_session="${ks_current_session:-}"
typeset -gA ks_active_map

# Build the rows. Needs `ks_current_session` and `ks_active_map` from the caller.
ks_picker_rows() {
    local entry session tag
    ks_find_entries | while IFS= read -r entry; do
        ks_session_path_for "$entry"
        session="$REPLY"

        if [[ "$session" == "$ks_current_session" ]]; then
            tag="$KS_TAG_CURRENT"
        elif (( ${+ks_active_map[$session]} )); then
            tag="$KS_TAG_ACTIVE"
        else
            tag="$KS_TAG_NONE"
        fi

        ks_pad "$KS_PAD" "$tag ${entry:h:t}/${entry:t}"
        print -r -- "$REPLY"$'\t'"[[${entry:h:h:t}]]"$'\t'"$session"$'\t'"$entry"
    done
}

# Run the picker and write the selected row to standard output. Returns non-zero
# when the user aborts.
ks_picker_run() {
    FZF_DEFAULT_OPTS="$KS_FZF_OPTS" "$KS_FZF"
}

# Read one field out of a selected row. Result in REPLY.
ks_selection_field() {
    local -a fields
    fields=("${(@ps:\t:)1}")
    REPLY="${fields[$2]:-}"
}
