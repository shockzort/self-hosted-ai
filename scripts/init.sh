#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

mkdir -p \
  data/comfyui/input \
  data/comfyui/output/text-to-image \
  data/comfyui/output/text-to-video \
  data/comfyui/output/image-edit \
  data/comfyui/output/style-transfer \
  data/comfyui/output/audio \
  data/comfyui/output/character \
  data/comfyui/models/checkpoints \
  data/comfyui/models/diffusion_models \
  data/comfyui/models/text_encoders \
  data/comfyui/models/vae \
  data/comfyui/models/loras \
  data/comfyui/models/controlnet \
  data/comfyui/models/clip_vision \
  data/comfyui/models/model_patches \
  data/comfyui/models/upscale_models \
  data/comfyui/custom_nodes \
  data/comfyui/user \
  data/ollama \
  data/open-webui \
  data/prometheus \
  data/grafana \
  workflows/text-to-image \
  workflows/text-to-video \
  workflows/image-edit \
  workflows/style-transfer \
  workflows/character \
  workflows/audio

if [[ ! -f .env ]]; then
  cp .env.example .env
  sed -i "s/^PUID=.*/PUID=$(id -u)/" .env
  sed -i "s/^PGID=.*/PGID=$(id -g)/" .env
  echo "Created .env from .env.example"
fi

cat <<MSG
Workspace initialized.

Main URLs after start:
  ComfyUI:     http://localhost:${COMFYUI_PORT:-8188}
  Open WebUI:  http://localhost:${OPEN_WEBUI_PORT:-3000}
  Results:     http://localhost:${RESULTS_PORT:-8090}
  Grafana:     http://localhost:${GRAFANA_PORT:-3001}
MSG
