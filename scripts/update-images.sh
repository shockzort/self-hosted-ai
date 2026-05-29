#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/dcgm-image.sh"
resolve_dcgm_exporter_image
docker compose "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_GPU_FILES[@]}" pull
docker compose "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_GPU_FILES[@]}" build --pull comfyui
