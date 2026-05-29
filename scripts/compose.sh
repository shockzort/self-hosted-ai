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

needs_dcgm_resolution() {
  local arg
  for arg in "$@"; do
    case "${arg}" in
      up|pull|create)
        return 0
        ;;
    esac
  done

  return 1
}

if [[ "${MODE}" != "cpu" ]] && needs_dcgm_resolution "$@"; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/dcgm-image.sh"
  resolve_dcgm_exporter_image
fi

exec docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" "$@"
