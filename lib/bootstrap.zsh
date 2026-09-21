# Loader and fatal-error helpers.
#
# bin/kitty-sessionizer sources this file first, and must set KS_ROOT and KS_LIB
# before it does. $0 changes inside a sourced file, so a library cannot find the
# repository root on its own.

set -euo pipefail

typeset -gA _ks_loaded=()

# Source a library from lib/, once. A repeated call costs one hash lookup, so an
# action can declare every module it needs without counting the cost.
ks_use() {
    local mod
    for mod in "$@"; do
        (( ${+_ks_loaded[$mod]} )) && continue
        [[ -r "$KS_LIB/$mod.zsh" ]] || ks_die "unknown library: $mod"
        _ks_loaded[$mod]=1
        source "$KS_LIB/$mod.zsh"
    done
}

ks_die() {
    print -ru2 -- "kitty-sessionizer: $*"
    exit 1
}

# Report a missing tool by name and configured path. Without this the failure
# surfaces as "command not found" from inside a pipe, which hides the cause.
# A value with no slash is looked up in PATH and the variable is rewritten to the
# absolute path, so an override such as KS_FZF=cat also works.
ks_require_tools() {
    local var file
    for var in "$@"; do
        file="${(P)var:-}"
        [[ -n "$file" ]] || ks_die "$var is not set"
        if [[ "$file" != */* ]]; then
            file="${commands[$file]:-}"
            [[ -n "$file" ]] || ks_die "$var: not found in PATH: ${(P)var}"
            typeset -g "$var=$file"
        fi
        [[ -x "$file" ]] || ks_die "$var is not executable: $file"
    done
}
