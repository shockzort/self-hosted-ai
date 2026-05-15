#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/init.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
./scripts/install-comfy-workflows.sh "${COMFY_WORKFLOW_BUNDLE_ON_START:-starter}"
if [[ -n "${COMFY_MODEL_BUNDLE_ON_START:-}" ]]; then
  ./scripts/download-comfy-workflow-models.sh "${COMFY_MODEL_BUNDLE_ON_START}"
fi
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh || true
docker compose "${COMPOSE_ENV_ARGS[@]}" "${COMPOSE_CPU_FILES[@]}" up -d --build "$@"
./scripts/smoke-test.sh cpu
