#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

resolve_path() {
  local path="$1"
  case "${path}" in
    /*) printf '%s\n' "${path}" ;;
    *) printf '%s/%s\n' "${ROOT_DIR}" "${path#./}" ;;
  esac
}

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-self-hosted-ai}"
export SELF_HOSTED_AI_DATA_DIR
SELF_HOSTED_AI_DATA_DIR="$(resolve_path "${SELF_HOSTED_AI_DATA_DIR:-data}")"
export SELF_HOSTED_AI_WORKFLOWS_DIR
SELF_HOSTED_AI_WORKFLOWS_DIR="$(resolve_path "${SELF_HOSTED_AI_WORKFLOWS_DIR:-workflows}")"

COMPOSE_ENV_ARGS=()
if [[ -f .env ]]; then
  COMPOSE_ENV_ARGS=(--env-file .env)
fi

COMPOSE_GPU_FILES=(-f compose.yaml -f compose.gpu.yaml)
COMPOSE_CPU_FILES=(-f compose.yaml -f compose.cpu.yaml)
COMPOSE_CODE_LLM_GPU_FILES=(-f compose.yaml -f compose.gpu.yaml -f compose.code-llm.yaml -f compose.code-llm.gpu.yaml)
COMPOSE_CODE_LLM_CPU_FILES=(-f compose.yaml -f compose.cpu.yaml -f compose.code-llm.yaml -f compose.code-llm.cpu.yaml)
