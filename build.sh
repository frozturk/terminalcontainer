#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

docker build -t agent-base -f Dockerfile.base .
docker build -t opencode -f Dockerfile.opencode .
docker build -t claude-code -f Dockerfile.claude .
docker build -t codex -f Dockerfile.codex .
