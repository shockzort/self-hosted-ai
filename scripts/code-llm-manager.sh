#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

export CODE_LLM_MANAGER_REPO_DIR="${ROOT_DIR}"
export DOCKER_GID
DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"

manager_compose_files() {
  if [[ "${MODE:-gpu}" == "cpu" ]]; then
    printf '%s\n' -f compose.code-llm-manager.yaml -f compose.code-llm-manager.cpu.yaml
  else
    printf '%s\n' -f compose.code-llm-manager.yaml -f compose.code-llm-manager.gpu.yaml
  fi
}

compose() {
  local compose_files=()
  mapfile -t compose_files < <(manager_compose_files)
  docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" "$@"
}

url() {
  printf 'http://%s:%s\n' "${CODE_LLM_MANAGER_BIND:-127.0.0.1}" "${CODE_LLM_MANAGER_PORT:-8091}"
}

case "${1:-start}" in
  start)
    compose up -d --build code-llm-manager
    printf 'Code LLM Manager: %s\n' "$(url)"
    ;;
  stop)
    compose stop code-llm-manager
    ;;
  restart)
    compose up -d --build --force-recreate code-llm-manager
    printf 'Code LLM Manager: %s\n' "$(url)"
    ;;
  status)
    compose ps code-llm-manager
    ;;
  logs)
    compose logs -f code-llm-manager
    ;;
  run-host)
    cd "${ROOT_DIR}"
    exec python3 "${SCRIPT_DIR}/code-llm-manager.py" --host "${CODE_LLM_MANAGER_HOST:-127.0.0.1}" --port "${CODE_LLM_MANAGER_PORT:-8091}"
    ;;
  *)
    printf 'Usage: %s [start|stop|restart|status|logs|run-host]\n' "$0" >&2
    exit 2
    ;;
esac
