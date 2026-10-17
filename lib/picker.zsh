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
typeset -gA ks_picker_listed

() {
    local -a steps=(
        'until [ -e "$KS_PICKER_CACHE/done" ]; do sleep 0.05; done'
        'FZF_DEFAULT_OPTS= "$KS_FZF" --filter={q} --delimiter="\t" --nth=1 --no-sort < "$KS_PICKER_CACHE/open" || [ $? -eq 1 ]'
        'FZF_DEFAULT_OPTS= "$KS_FZF" --filter={q} --delimiter="\t" --nth=1 < "$KS_PICKER_CACHE/rest" || [ $? -eq 1 ]'
    )
    typeset -gr KS_PICKER_RANK="${(j:; :)steps}"
}

ks_picker_row() {
    local entry="$1" session="$2" tag="$KS_TAG_NONE"
    if [[ -n "$session" ]]; then
        if [[ "$session" == "$ks_current_session" ]]; then
            tag="$KS_TAG_CURRENT"
        elif (( ${+ks_active_map[$session]} )); then
            tag="$KS_TAG_ACTIVE"
        fi
    fi
    ks_pad "$KS_PAD" "$tag ${entry:h:t}/${entry:t}"
    REPLY="$REPLY"$'\t'"[[${entry:h:h:t}]]"$'\t'"$session"$'\t'"$entry"
}

ks_picker_open_rows() {
    typeset -gA ks_picker_listed=()
    local session
    local -a order=() rows=()

    ks_read_lines "$KS_ACTIVE_TRACKER"
    for session in "${reply[@]}"; do
        (( ${+ks_active_map[$session]} )) || continue
        [[ "$session" == "$ks_current_session" ]] && continue
        order+=("$session")
    done
    if (( ${+ks_active_map[$ks_current_session]} )); then
        order+=("$ks_current_session")
    fi

    for session in "${order[@]}"; do
        ks_tracker_project "$session"
        [[ -n "$REPLY" && -d "$REPLY" ]] || continue
        ks_picker_listed[$session]=1
        ks_picker_row "$REPLY" "$session"
        rows+=("$REPLY")
    done
    typeset -ga reply=("${rows[@]}")
}

# Build the rows of what fd finds, less the sessions that `ks_picker_open_rows`
# listed. Needs `ks_current_session` and `ks_active_map` from the caller.
#
# Only a directory is a project. A plain file opens in the editor and never
# enters a session, so it gets no session field and no marker. Without that a
# file marks itself as the current session as soon as its name matches the name
# of the session, because a session is named after the last part of the path.
ks_picker_rows() {
    local entry session
    local -A seen=()
    ks_find_entries | while IFS= read -r entry; do
        (( ${+seen[${entry%/}]} )) && continue
        seen[${entry%/}]=1
        session=""
        if [[ -d "$entry" ]]; then
            ks_session_path_for "$entry"
            session="$REPLY"
            (( ${+ks_picker_listed[$session]} )) && continue
        fi
        ks_picker_row "$entry" "$session"
        print -r -- "$REPLY"
    done
}

ks_picker_feed() {
    local dir="$1"
    ks_picker_open_rows
    ks_write_lines "$dir/open" "${reply[@]}"
    if (( ${#reply} )); then
        print -rl -- "${reply[@]}"
    fi
    ks_picker_rows | { tee "$dir/rest"; : > "$dir/done" }
}

# Run the picker over the rows on standard input and write the selected row to
# standard output. Returns non-zero when the user aborts. The first argument is
# the directory that `ks_picker_feed` fills. The second is the fzf options to
# use, so an action with its own list can bring its own picker look.
ks_picker_run() {
    KS_FZF="$KS_FZF" KS_PICKER_CACHE="$1" FZF_DEFAULT_OPTS="${2:-$KS_FZF_OPTS}" \
        "$KS_FZF" --no-sort --bind "change:reload-sync:$KS_PICKER_RANK"
}

# Read one field out of a selected row. Result in REPLY.
ks_selection_field() {
    local -a fields
    fields=("${(@ps:\t:)1}")
    REPLY="${fields[$2]:-}"
}
