#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-gpu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

if [[ "${MODE}" == "cpu" ]]; then
  compose_files=("${COMPOSE_CPU_FILES[@]}")
else
  compose_files=("${COMPOSE_GPU_FILES[@]}")
fi

docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" ps

check_url() {
  local name="$1"
  local url="$2"
  local attempts="${3:-30}"
  local delay="${4:-2}"
  local curl_timeout="${SMOKE_CURL_TIMEOUT:-5}"
  local status_every="${SMOKE_STATUS_EVERY:-10}"
  local attempt

  for attempt in $(seq 1 "${attempts}"); do
    if curl -fsS --max-time "${curl_timeout}" "${url}" >/dev/null 2>&1; then
      printf '[ok] %s is reachable at %s\n' "${name}" "${url}"
      return 0
    fi

    if [[ "${attempt}" -eq 1 || ( "${status_every}" -gt 0 && $((attempt % status_every)) -eq 0 ) ]]; then
      printf '[wait] %s is not ready yet at %s (%s/%s)\n' "${name}" "${url}" "${attempt}" "${attempts}" >&2
    fi

    sleep "${delay}"
  done

  printf '[fail] %s is not reachable at %s\n' "${name}" "${url}" >&2
  return 1
}

check_url "ComfyUI" "http://127.0.0.1:${COMFYUI_PORT:-8188}/system_stats" "${SMOKE_COMFY_ATTEMPTS:-300}" "${SMOKE_DELAY:-2}"
check_url "Open WebUI" "http://127.0.0.1:${OPEN_WEBUI_PORT:-3000}/" "${SMOKE_OPEN_WEBUI_ATTEMPTS:-60}" "${SMOKE_DELAY:-2}"
check_url "Results browser" "http://127.0.0.1:${RESULTS_PORT:-8090}/" "${SMOKE_RESULTS_ATTEMPTS:-30}" "${SMOKE_DELAY:-2}"
check_url "Prometheus" "http://127.0.0.1:${PROMETHEUS_PORT:-9090}/-/ready" "${SMOKE_PROMETHEUS_ATTEMPTS:-30}" "${SMOKE_DELAY:-2}"
check_url "Grafana" "http://127.0.0.1:${GRAFANA_PORT:-3001}/api/health" "${SMOKE_GRAFANA_ATTEMPTS:-30}" "${SMOKE_DELAY:-2}"
