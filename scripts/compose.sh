#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

MODE="${MODE:-gpu}"
if [[ "${MODE}" == "cpu" ]]; then
  compose_files=("${COMPOSE_CPU_FILES[@]}")
else
  compose_files=("${COMPOSE_GPU_FILES[@]}")
fi

exec docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" "$@"
