#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-gpu}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

if [[ "${MODE}" == "cpu" ]]; then
  compose_files=("${COMPOSE_CPU_FILES[@]}")
else
  compose_files=("${COMPOSE_GPU_FILES[@]}")
fi

if [[ "$#" -gt 0 ]]; then
  models=("$@")
else
  read -r -a models <<< "${OLLAMA_MODELS:-qwen3:14b gemma3:12b deepseek-r1:14b}"
fi

docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" up -d ollama

for model in "${models[@]}"; do
  echo "Pulling Ollama model: ${model}"
  docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" exec -T ollama ollama pull "${model}"
done
