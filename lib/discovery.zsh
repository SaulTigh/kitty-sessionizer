# Find the things the picker can select.

ks_use config
ks_require_tools KS_FD

# Write one path per line: the entries under each search path, in the order the
# paths are listed, then the files in the home directory. The output streams, so
# the picker draws its first rows before the search finishes.
#
# A search path that no longer exists is skipped instead of ending the run.
ks_find_entries() {
    local path
    for path in "${KS_SEARCH_PATHS[@]}"; do
        [[ -d "$path" ]] || continue
        "$KS_FD" --hidden -d "$KS_DEPTH" . "$path" || true
    done

    if [[ -d "$KS_HOME_FILE_PATH" ]]; then
        "$KS_FD" --hidden -t f -d "$KS_DEPTH" . "$KS_HOME_FILE_PATH" || true
    fi
}
