#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-gpu}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/init.sh >/dev/null

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

if [[ "$#" -gt 0 ]]; then
  models=("$@")
else
  read -r -a models <<< "${OLLAMA_MODELS:-qwen3:14b gemma3:12b deepseek-r1:14b}"
fi

docker compose --env-file .env "${compose_files[@]}" up -d ollama

for model in "${models[@]}"; do
  echo "Pulling Ollama model: ${model}"
  docker compose --env-file .env "${compose_files[@]}" exec -T ollama ollama pull "${model}"
done
