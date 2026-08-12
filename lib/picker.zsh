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
#
# Only a directory is a project. A plain file opens in the editor and never
# enters a session, so it gets no session field and no marker. Without that a
# file marks itself as the current session as soon as its name matches the name
# of the session, because a session is named after the last part of the path.
ks_picker_rows() {
    local entry session tag
    ks_find_entries | while IFS= read -r entry; do
        session=""
        if [[ -d "$entry" ]]; then
            ks_session_path_for "$entry"
            session="$REPLY"
        fi

        tag="$KS_TAG_NONE"
        if [[ -n "$session" ]]; then
            if [[ "$session" == "$ks_current_session" ]]; then
                tag="$KS_TAG_CURRENT"
            elif (( ${+ks_active_map[$session]} )); then
                tag="$KS_TAG_ACTIVE"
            fi
        fi

        ks_pad "$KS_PAD" "$tag ${entry:h:t}/${entry:t}"
        print -r -- "$REPLY"$'\t'"[[${entry:h:h:t}]]"$'\t'"$session"$'\t'"$entry"
    done
}

# Run the picker over the rows on standard input and write the selected row to
# standard output. Returns non-zero when the user aborts. The argument is the fzf
# options to use, so an action with its own list can bring its own picker look.
ks_picker_run() {
    FZF_DEFAULT_OPTS="${1:-$KS_FZF_OPTS}" "$KS_FZF"
}

# Read one field out of a selected row. Result in REPLY.
ks_selection_field() {
    local -a fields
    fields=("${(@ps:\t:)1}")
    REPLY="${fields[$2]:-}"
}
