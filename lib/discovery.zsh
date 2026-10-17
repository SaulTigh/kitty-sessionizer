# Find the things the picker can select.

ks_use config
ks_require_tools KS_FD

# Write one path per line: search results, chosen folders, then home files.
# The output streams, so the picker draws rows before the search finishes.
#
# A search path that no longer exists is skipped instead of ending the run.
# The home files are listed once when home is a search path.
ks_find_entries() {
    local dir
    for dir in "${KS_SEARCH_PATHS[@]}"; do
        [[ -d "$dir" ]] || continue
        if [[ -z "$KS_HOME_FILE_PATH" && "${dir%/}" == "${HOME%/}" ]]; then
            "$KS_FD" --hidden -t d -d "$KS_DEPTH" . "$dir" || true
        else
            "$KS_FD" --hidden -d "$KS_DEPTH" . "$dir" || true
        fi
    done

    for dir in "${KS_EXTRA_PROJECT_PATHS[@]}"; do
        [[ -d "$dir" ]] && print -r -- "$dir"
    done

    [[ -n "$KS_HOME_FILE_PATH" ]] || return 0
    (( ${KS_SEARCH_PATHS[(Ie)$KS_HOME_FILE_PATH]} )) && return 0
    if [[ -d "$KS_HOME_FILE_PATH" ]]; then
        "$KS_FD" --hidden -t f -d "$KS_DEPTH" . "$KS_HOME_FILE_PATH" || true
    fi
}
