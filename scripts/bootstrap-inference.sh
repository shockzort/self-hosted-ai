#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

BUNDLE="${1:-starter}"
MODE="${MODE:-gpu}"

./scripts/init.sh
./scripts/install-comfy-workflows.sh "${BUNDLE}"
./scripts/download-comfy-workflow-models.sh "${BUNDLE}"

if [[ "${SKIP_LLM:-0}" != "1" ]]; then
  MODE="${MODE}" ./scripts/pull-ollama-models.sh
fi

echo "Bootstrap completed for bundle: ${BUNDLE}"
