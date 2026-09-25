# Terminal output. Every action prints through these, so a colour change happens
# in lib/config.zsh only.

ks_use config

ks_info()  { print -r -- "$*" }
ks_ok()    { print -r -- "${KS_C_OK}$*${KS_C_RESET}" }
ks_warn()  { print -r -- "${KS_C_WARN}$*${KS_C_RESET}" }
ks_dim()   { print -r -- "${KS_C_DIM}$*${KS_C_RESET}" }
ks_blank() { print -r -- "" }

# Print the line that offers the keys. Every [key] in the text takes the key
# colour, so the choices stand out from the words that describe them.
# A bracket has to be escaped in the pattern but not in the replacement, so the
# replacement takes it from a variable and no backslash reaches the output.
ks_keys() {
    local text="$*" open='[' close=']'
    text="${text//\[/${KS_C_KEY}${open}}"
    text="${text//\]/${close}${KS_C_RESET}}"
    print -r -- "$text"
}

# Read one key without an echo. The key lands in REPLY. A closed input gives an
# empty REPLY, which every caller reads as "cancel".
#
# `read -k` opens /dev/tty, which is right in the kitty overlay but fails when
# the action is driven from a script or a pipe. Fall back to standard input so
# an action stays testable.
ks_read_key() {
    REPLY=""
    if [[ -t 0 ]]; then
        read -rsk1 REPLY || REPLY=""
    else
        read -rk1 -u 0 REPLY || REPLY=""
    fi
}

# kitty closes the overlay window as soon as the action returns, so a result has
# to wait for the reader.
ks_pause() {
    print -r -- "${KS_C_DIM}${1:-Press any key to close…}${KS_C_RESET}"
    ks_read_key
}
