if [ -n "$ZSH_VERSION" ]; then
    _CC_DIR="${${(%):-%x}:A:h}"
else
    _CC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Refuse to mount an overly broad directory (home or filesystem root).
_cc_guard() {
    local here="$(pwd)"
    if [ "$here" = "$HOME" ] || [ "$here" = "/" ]; then
        echo "refusing to mount $here — cd into a project directory first" >&2
        return 1
    fi
}

_cc_env() {
    if [ ! -f "$1" ]; then
        echo "missing $1 (copy the matching .env.example and add your key)" >&2
        return 1
    fi
}

# Stable per-repo mount point: agents key their session history by cwd, so a
# shared /work makes `--resume` show sessions from every repo at once. Mounting
# each repo under /work/<host-path> gives it its own directory, scoping resume
# to just that folder while staying stable and readable across runs.
_cc_mount() {
    printf '/work%s' "$(pwd)"
}

# Isolation: no extra capabilities, no privilege escalation, only /work and
# the agent's config dir are writable, host gitconfig is read-only.
_CC_HARDEN=(--init --cap-drop ALL --security-opt no-new-privileges)

copencode() {
    _cc_guard || return 1
    _cc_env "$_CC_DIR/opencode.env" || return 1
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    local mount; mount="$(_cc_mount)"
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):$mount" -w "$mount" \
        "${git_args[@]}" \
        --env-file "$_CC_DIR/opencode.env" \
        opencode "$@"
}

cclaude() {
    _cc_guard || return 1
    mkdir -p "$_CC_DIR/.claude-home"
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    local mount; mount="$(_cc_mount)"
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):$mount" -w "$mount" \
        -v "$_CC_DIR/.claude-home:/config" \
        "${git_args[@]}" \
        claude-code --dangerously-skip-permissions "$@"
}

ccodex() {
    _cc_guard || return 1
    mkdir -p "$_CC_DIR/.codex-home"
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    local mount; mount="$(_cc_mount)"
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):$mount" -w "$mount" \
        -v "$_CC_DIR/.codex-home:/config" \
        "${git_args[@]}" \
        codex --dangerously-bypass-approvals-and-sandbox "$@"
}
