# Thin wrappers over gum. Every prompt here needs a tty, which the kitty overlay
# gives. gum exits non-zero on Esc and on Ctrl-C, and each wrapper turns that
# into an empty REPLY, which every caller reads as "cancel".

ks_use config
ks_require_tools KS_GUM

# gum draws at the cursor and has no way to centre itself, so the left margin
# is computed once from the width of the terminal and given to each prompt as
# padding. The lines an action prints between prompts take the same margin.
typeset -gi ks_gum_left=$(( (COLUMNS - KS_GUM_WIDTH) / 2 ))
(( ks_gum_left > 0 )) || ks_gum_left=0
typeset -g ks_gum_pad="0 0 0 $ks_gum_left"
typeset -g ks_gum_indent="${(l:ks_gum_left:):-}"

# Print a line at the margin of the column.
ks_gum_line() { print -r -- "${ks_gum_indent}$*" }

# gum erases its own view when it exits, so an answered prompt would vanish.
# Print the header and the answer back, so the answers stay on screen.
ks_gum_answered() {
    ks_gum_line "${KS_C_LABEL}$1${KS_C_RESET} ${KS_C_PROMPT}${KS_GUM_PROMPT}${KS_C_RESET}$2"
}

# Read one line. Arguments: header, default value, placeholder. Result in REPLY.
# A paste can carry a newline or a space at either end, and a URL with one of
# those in it is not a URL any more.
ks_gum_input() {
    setopt local_options extended_glob
    REPLY="$("$KS_GUM" input --header "$1" --value "${2:-}" \
        --placeholder "${3:-}" --prompt "$KS_GUM_PROMPT" \
        --width "$KS_GUM_WIDTH" --padding "$ks_gum_pad")" || REPLY=""
    REPLY="${${REPLY##[[:space:]]##}%%[[:space:]]##}"
    [[ -z "$REPLY" ]] || ks_gum_answered "$1" "$REPLY"
    return 0
}

# Pick one line out of standard input. Argument: header. Result in REPLY.
# A list of one is taken without a prompt.
ks_gum_choose() {
    REPLY="$("$KS_GUM" choose --header "$1" --select-if-one \
        --padding "$ks_gum_pad")" || REPLY=""
    [[ -z "$REPLY" ]] || ks_gum_answered "$1" "$REPLY"
    return 0
}

# Pick any number of lines out of standard input. Argument: header. Result in
# the array `reply`, which is empty on cancel and on no pick.
ks_gum_choose_many() {
    local out item
    typeset -ga reply=()
    out="$("$KS_GUM" choose --header "$1" --no-limit \
        --padding "$ks_gum_pad")" || out=""
    [[ -n "$out" ]] || return 0
    reply=("${(@f)out}")
    ks_gum_line "${KS_C_LABEL}$1${KS_C_RESET}"
    for item in "${reply[@]}"; do
        ks_gum_line "  $item"
    done
    return 0
}

# Ask a yes-or-no question. Arguments: prompt, yes label, no label. Returns 0
# for yes, and non-zero for no and for cancel.
ks_gum_confirm() {
    local -i rc=0
    "$KS_GUM" confirm "$1" --affirmative "$2" --negative "$3" \
        --padding "$ks_gum_pad" || rc=$?
    case $rc in
        0) ks_gum_answered "$1" "$2" ;;
        1) ks_gum_answered "$1" "$3" ;;
    esac
    return $rc
}

# Run a command behind a spinner. Argument 1 is the title, the rest is the
# command. The output of the command is shown only when it fails, so a failed
# clone still tells why. Returns the exit code of the command.
ks_gum_spin() {
    local title="$1"
    shift
    "$KS_GUM" spin --title "$title" --show-error --padding "$ks_gum_pad" -- "$@"
}
