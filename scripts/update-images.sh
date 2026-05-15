#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/init.sh >/dev/null
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml pull
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml build --pull comfyui
