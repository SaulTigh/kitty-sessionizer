# Find the things the picker can select.

ks_use config
ks_require_tools KS_FD

# Write one path per line: the folders under each search path, the files and
# folders under each file search path, then chosen folders. The output streams,
# so the picker draws rows before the search finishes.
#
# A search path that no longer exists is skipped instead of ending the run.
ks_find_entries() {
    local dir
    for dir in "${KS_SEARCH_PATHS[@]}"; do
        [[ -d "$dir" ]] || continue
        "$KS_FD" --hidden -t d -d "$KS_DEPTH" . "$dir" || true
    done

    for dir in "${KS_FILE_SEARCH_PATHS[@]}"; do
        [[ -d "$dir" ]] || continue
        "$KS_FD" --hidden -d "$KS_DEPTH" . "$dir" || true
    done

    for dir in "${KS_EXTRA_PROJECT_PATHS[@]}"; do
        [[ -d "$dir" ]] && print -r -- "$dir"
    done
}
