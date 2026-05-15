#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/init.sh
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
./scripts/install-comfy-workflows.sh "${COMFY_WORKFLOW_BUNDLE_ON_START:-starter}"
if [[ -n "${COMFY_MODEL_BUNDLE_ON_START:-}" ]]; then
  ./scripts/download-comfy-workflow-models.sh "${COMFY_MODEL_BUNDLE_ON_START}"
fi
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh || true
docker compose --env-file .env -f compose.yaml -f compose.cpu.yaml up -d --build "$@"
./scripts/smoke-test.sh cpu
