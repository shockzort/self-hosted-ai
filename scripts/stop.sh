#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

docker compose "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_GPU_FILES[@]}" down "$@"
