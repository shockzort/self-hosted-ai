#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-gpu}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

compose_files=(-f compose.yaml)
if [[ "${MODE}" == "cpu" ]]; then
  compose_files+=(-f compose.cpu.yaml)
else
  compose_files+=(-f compose.gpu.yaml)
fi

docker compose --env-file .env "${compose_files[@]}" ps

check_url() {
  local name="$1"
  local url="$2"
  local attempts="${3:-30}"
  local delay="${4:-2}"

  for _ in $(seq 1 "${attempts}"); do
    if curl -fsS --max-time 5 "${url}" >/dev/null 2>&1; then
      printf '[ok] %s is reachable at %s\n' "${name}" "${url}"
      return 0
    fi
    sleep "${delay}"
  done

  printf '[fail] %s is not reachable at %s\n' "${name}" "${url}" >&2
  return 1
}

check_url "ComfyUI" "http://127.0.0.1:${COMFYUI_PORT:-8188}/system_stats" 60 2
check_url "Open WebUI" "http://127.0.0.1:${OPEN_WEBUI_PORT:-3000}/" 60 2
check_url "Results browser" "http://127.0.0.1:${RESULTS_PORT:-8090}/" 30 2
check_url "Prometheus" "http://127.0.0.1:${PROMETHEUS_PORT:-9090}/-/ready" 30 2
check_url "Grafana" "http://127.0.0.1:${GRAFANA_PORT:-3001}/api/health" 30 2
