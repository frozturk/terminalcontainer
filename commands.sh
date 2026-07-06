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
# shared /work makes `--resume` show sessions from every repo at once. Deriving
# a deterministic slug from the host path gives each repo its own /work/<slug>,
# scoping resume to just that folder. The hash must be stable (not random) so
# the same repo always maps to the same slug across runs.
_cc_slug() {
    local p="$(pwd)" hash base parent name
    if command -v md5sum >/dev/null 2>&1; then
        hash="$(printf '%s' "$p" | md5sum | cut -c1-10)"
    else
        hash="$(printf '%s' "$p" | md5 | cut -c1-10)"
    fi
    base="$(basename "$p")"
    parent="$(basename "$(dirname "$p")")"
    if [ -n "$parent" ] && [ "$parent" != "/" ] && [ "$parent" != "." ]; then
        name="${parent}_${base}"
    else
        name="$base"
    fi
    printf '%s_%s' "$hash" "$name"
}

# Isolation: no extra capabilities, no privilege escalation, only /work and
# the agent's config dir are writable, host gitconfig is read-only.
_CC_HARDEN=(--init --cap-drop ALL --security-opt no-new-privileges)

copencode() {
    _cc_guard || return 1
    _cc_env "$_CC_DIR/opencode.env" || return 1
    local slug; slug="$(_cc_slug)"
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):/work/$slug" -w "/work/$slug" \
        "${git_args[@]}" \
        --env-file "$_CC_DIR/opencode.env" \
        opencode "$@"
}

cclaude() {
    _cc_guard || return 1
    mkdir -p "$_CC_DIR/.claude-home"
    local slug; slug="$(_cc_slug)"
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):/work/$slug" -w "/work/$slug" \
        -v "$_CC_DIR/.claude-home:/config" \
        "${git_args[@]}" \
        claude-code --dangerously-skip-permissions "$@"
}

ccodex() {
    _cc_guard || return 1
    mkdir -p "$_CC_DIR/.codex-home"
    local slug; slug="$(_cc_slug)"
    local git_args=()
    [ -f "$HOME/.gitconfig" ] && git_args=(-v "$HOME/.gitconfig:/gitconfig:ro" -e GIT_CONFIG_GLOBAL=/gitconfig)
    docker run "${_CC_HARDEN[@]}" -it --rm \
        -v "$(pwd):/work/$slug" -w "/work/$slug" \
        -v "$_CC_DIR/.codex-home:/config" \
        "${git_args[@]}" \
        codex --dangerously-bypass-approvals-and-sandbox "$@"
}
