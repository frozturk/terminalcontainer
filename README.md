# Containerized coding agents

Run [opencode](https://opencode.ai), [Claude Code](https://claude.com/claude-code),
and [Codex](https://developers.openai.com/codex) in locked-down Docker containers
while editing files on your host. Everything lives in this directory.

Each agent has its own image, all built on a shared `agent-base` that bundles the
CLI tools these agents reach for: `git`, `ripgrep`, `fd`, `fzf`, `jq`, `gh`,
`tree`, `tmux`, `lsof`, `vim`/`nano`, `zip`/`unzip`, `python3`/`pip`/`venv`,
`curl`/`wget`, `openssh-client`, and a build toolchain (`make`, `gcc`). Locale is
`C.UTF-8` for correct TUI rendering.

## Build

```sh
./build.sh
```

Builds `agent-base`, then `opencode`, `claude-code`, and `codex`.

## Install the commands

```sh
echo "source $(pwd)/commands.sh" >> ~/.zshrc
source ~/.zshrc
```

Defines `copencode`, `cclaude`, and `ccodex`.

## Use

From a project directory (mounted at `/work`, so changes land on your host):

```sh
copencode .   # opencode  — uses an API key (see Auth)
cclaude       # Claude Code — log in on first run
ccodex        # Codex — log in on first run
```

## Auth

- **opencode**: reads `OPENCODE_API_KEY` from a gitignored env file and routes to
  [Neuralwatt](https://neuralwatt.com) (`glm-5.2`). The Neuralwatt provider is
  defined only in `opencode.json`.
  ```sh
  cp opencode.env.example opencode.env && chmod 600 opencode.env
  # set OPENCODE_API_KEY (a Neuralwatt key) in opencode.env
  ```
- **Claude Code / Codex**: normal interactive login, persisted in gitignored local
  dirs (`.claude-home/`, `.codex-home/`) so you log in once.

  _Alternative — seed from an existing host login:_ instead of logging in inside
  the container, copy your host credentials into the mounted config dirs. The
  container points each CLI at `/config` (`CLAUDE_CONFIG_DIR` / `CODEX_HOME`),
  which maps to these dirs:
  ```sh
  mkdir -p .claude-home && cp -a ~/.claude/. .claude-home/   # Claude Code
  mkdir -p .codex-home  && cp -a ~/.codex/.  .codex-home/    # Codex
  ```
  Then run `cclaude` / `ccodex` and you're already logged in. Note: on macOS
  Claude Code may store its token in the Keychain rather than in `~/.claude`, in
  which case copying the files won't carry the login — use the interactive login
  above instead.

## Permissions

Agents run fully autonomous inside the container (the container is the sandbox):
Claude Code with `--dangerously-skip-permissions`, Codex with
`--dangerously-bypass-approvals-and-sandbox`, opencode with all permissions set to
`allow` in `opencode.json`.

## Isolation

- **Only three things from the host are exposed**: the current directory (`/work`,
  read-write — that's how edits reach your host), the agent's own config dir, and
  `~/.gitconfig` (read-only, for commit identity). Nothing else of your host
  filesystem is visible — on macOS the container runs in Docker Desktop's LinuxKit
  VM, so only explicitly mounted paths exist inside.
- **Hardened runtime**: `--cap-drop ALL`, `--security-opt no-new-privileges`, and
  `--init` for clean signal handling.
- **Mount guard**: the commands refuse to run from your home directory or `/`, so
  you can't accidentally hand an agent your whole home.
- Because of `--cap-drop ALL`, containers **cannot install system packages at
  runtime**. When a task needs one, add it to `Dockerfile.base` and re-run
  `./build.sh` (cached layers make this quick).
- Residual: outbound network is open (required to reach the model APIs). Tighten
  with a custom Docker network + egress rules if needed.
