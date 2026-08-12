# Thin wrappers over git.

ks_use config
ks_require_tools KS_GIT

# The repository name inside a clone URL. Everything up to the last / or : goes,
# because the ssh short form git@host:group/repo.git has no scheme to parse.
# A .git suffix goes too. Result in REPLY.
ks_git_repo_name() {
    local url="$1"
    while [[ "$url" == */ ]]; do
        url="${url%/}"
    done
    REPLY="${url##*[/:]}"
    REPLY="${REPLY%.git}"
}

# Clone into a destination that does not exist yet. The output stays on the
# terminal, so the progress meter reaches the overlay.
ks_git_clone() {
    "$KS_GIT" clone -- "$1" "$2"
}
