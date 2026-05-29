#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

set_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s#^${key}=.*#${key}=${value}#" .env
  else
    printf '%s=%s\n' "${key}" "${value}" >> .env
  fi
}

replace_env_value() {
  local key="$1"
  local old_value="$2"
  local new_value="$3"
  if grep -q "^${key}=${old_value}$" .env; then
    sed -i "s#^${key}=.*#${key}=${new_value}#" .env
  fi
}

if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s/^PUID=.*/PUID=$(id -u)/" .env
  sed -i "s/^PGID=.*/PGID=$(id -g)/" .env
  echo "Created .env from .env.example"
fi

replace_env_value COMPOSE_PROJECT_NAME self-hosted-imgen self-hosted-ai
replace_env_value COMFYUI_IMAGE self-hosted-imgen-comfyui self-hosted-ai-comfyui
grep -q '^SELF_HOSTED_AI_DATA_DIR=' .env || set_env SELF_HOSTED_AI_DATA_DIR ./data
grep -q '^SELF_HOSTED_AI_WORKFLOWS_DIR=' .env || set_env SELF_HOSTED_AI_WORKFLOWS_DIR ./workflows
grep -q '^DCGM_EXPORTER_IMAGE=' .env || set_env DCGM_EXPORTER_IMAGE nvidia/dcgm-exporter
replace_env_value DCGM_EXPORTER_TAG 4.5.3-4.8.2-distroless 4.5.2-4.8.1-distroless
grep -q '^DCGM_EXPORTER_AUTO_FALLBACK=' .env || set_env DCGM_EXPORTER_AUTO_FALLBACK 1
grep -q '^DCGM_EXPORTER_FALLBACK_IMAGES=' .env || set_env DCGM_EXPORTER_FALLBACK_IMAGES '"nvcr.io/nvidia/k8s/dcgm-exporter:4.5.3-4.8.2-distroless nvidia/dcgm-exporter:4.5.2-4.8.1-distroless"'
grep -q '^COMFYUI_REQUIREMENTS_CACHE=' .env || set_env COMFYUI_REQUIREMENTS_CACHE 1
grep -q '^COMFYUI_REQUIREMENTS_PIP_ARGS=' .env || set_env COMFYUI_REQUIREMENTS_PIP_ARGS '"--timeout 60 --retries 5"'
grep -q '^COMFYUI_REQUIREMENTS_SKIP=' .env || set_env COMFYUI_REQUIREMENTS_SKIP ''
grep -q '^SMOKE_STATUS_EVERY=' .env || set_env SMOKE_STATUS_EVERY 10
grep -q '^SMOKE_CURL_TIMEOUT=' .env || set_env SMOKE_CURL_TIMEOUT 5
grep -q '^SMOKE_DELAY=' .env || set_env SMOKE_DELAY 2
grep -q '^SMOKE_COMFY_ATTEMPTS=' .env || set_env SMOKE_COMFY_ATTEMPTS 300

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/env.sh"

mkdir -p \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/input" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/text-to-image" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/text-to-video" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/image-edit" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/style-transfer" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/audio" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/output/character" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/checkpoints" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/diffusion_models" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/text_encoders" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/vae" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/loras" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/controlnet" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/clip_vision" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/model_patches" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/models/upscale_models" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/custom_nodes" \
  "${SELF_HOSTED_AI_DATA_DIR}/comfyui/user" \
  "${SELF_HOSTED_AI_DATA_DIR}/ollama" \
  "${SELF_HOSTED_AI_DATA_DIR}/code-llm/models" \
  "${SELF_HOSTED_AI_DATA_DIR}/code-llm-manager" \
  "${SELF_HOSTED_AI_DATA_DIR}/llama.cpp" \
  "${SELF_HOSTED_AI_DATA_DIR}/huggingface" \
  "${SELF_HOSTED_AI_DATA_DIR}/open-webui" \
  "${SELF_HOSTED_AI_DATA_DIR}/prometheus" \
  "${SELF_HOSTED_AI_DATA_DIR}/grafana" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/text-to-image" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/text-to-video" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/image-edit" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/style-transfer" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/character" \
  "${SELF_HOSTED_AI_WORKFLOWS_DIR}/audio"

cat <<MSG
Workspace initialized.

Project: ${COMPOSE_PROJECT_NAME}
Data dir: ${SELF_HOSTED_AI_DATA_DIR}
Workflows dir: ${SELF_HOSTED_AI_WORKFLOWS_DIR}

Main URLs after start:
  ComfyUI:     http://localhost:${COMFYUI_PORT:-8188}
  Open WebUI:  http://localhost:${OPEN_WEBUI_PORT:-3000}
  Results:     http://localhost:${RESULTS_PORT:-8090}
  Grafana:     http://localhost:${GRAFANA_PORT:-3001}
MSG
