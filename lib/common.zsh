# The prelude. bin/kitty-sessionizer loads this before it runs an action, so an
# action always starts with the configuration, the output helpers, and the small
# helpers below.
#
# A helper belongs here only when two or more modules call it and it knows
# nothing about kitty or about sessions. Anything that names a session file or a
# kitten command goes in its own module. That rule keeps this file small.

ks_use config ui

# Read a file into the array `reply`, one element per line. A missing or empty
# file gives an empty array, which every caller reads as "no state yet".
ks_read_lines() {
    typeset -ga reply=()
    [[ -r "$1" ]] || return 0
    local content
    content="$(<"$1")"
    [[ -n "$content" ]] || return 0
    reply=("${(@f)content}")
}

ks_write_lines() {
    local file="$1"
    shift
    if (( $# )); then
        print -rl -- "$@" > "$file"
    else
        : > "$file"
    fi
}

# Append a line only when the file does not hold it already. Without this the
# tracker files gain a duplicate on every switch and never shrink.
ks_append_unique() {
    local file="$1" value="$2" line
    ks_read_lines "$file"
    for line in "${reply[@]}"; do
        [[ "$line" == "$value" ]] && return 0
    done
    print -r -- "$value" >> "$file"
}

# Pad a string on the right to a fixed width. Result in REPLY.
ks_pad() {
    local -i width=$1
    REPLY="${(r:width:)2}"
}

# Pick the singular or the plural form for a count. Result in REPLY.
ks_plural() {
    local -i count=$1
    if (( count == 1 )); then
        REPLY="$2"
    else
        REPLY="${3:-${2}s}"
    fi
}
