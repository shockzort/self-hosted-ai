# Operations

## Запуск

```bash
cp .env.example .env
./scripts/preflight.sh
./scripts/start.sh
```

GPU-режим использует `compose.yaml + compose.gpu.yaml`. CPU fallback использует `compose.yaml + compose.cpu.yaml`:

```bash
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh
./scripts/start-cpu.sh
```

`./scripts/start.sh` перед запуском ставит ComfyUI workflow JSON из `COMFY_WORKFLOW_BUNDLE_ON_START` (`starter` по умолчанию). Если нужно также автоматически скачивать модели на старте, задайте `COMFY_MODEL_BUNDLE_ON_START=starter` в `.env`.

## UI credentials

Grafana:

- URL: `http://<host-ip>:3001`
- login: `GF_SECURITY_ADMIN_USER` из `.env`, по умолчанию `admin`
- password: `GF_SECURITY_ADMIN_PASSWORD` из `.env`, по умолчанию `change-me`

Если пароль Grafana меняется после создания `data/grafana/grafana.db`, сбросьте его внутри контейнера:

```bash
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml exec grafana grafana-cli admin reset-admin-password '<new-password>'
```

Open WebUI:

- URL: `http://<host-ip>:3000`
- signup включен через `OPEN_WEBUI_ENABLE_SIGNUP=true`
- если база пустая, первый зарегистрированный пользователь становится admin
- последующие пользователи получают `DEFAULT_USER_ROLE`, по умолчанию `user`

Если регистрация была запрещена старой конфигурацией:

```bash
./scripts/open-webui-enable-signup.sh
```

## Grafana dashboards

Dashboards provisioned from `monitoring/grafana/dashboards` into folder `Inference`:

- `Inference Overview`: общий обзор GPU/VRAM/RAM/container CPU/container memory.
- `GPU / DCGM Deep Dive`: температура, питание, SM/memory clocks, PCIe, tensor/DRAM activity.
- `Host & Containers`: scrape health, load, CPU throttling, OOM events, network, filesystem IO.

Перегенерировать dashboard JSON:

```bash
./scripts/generate-grafana-dashboards.py
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml restart grafana
```

## Доступ из локальной сети

Узнайте адрес хоста:

```bash
hostname -I
```

Откройте с телефона `http://<host-ip>:8188` для ComfyUI или `http://<host-ip>:3000` для Open WebUI. Если не открывается, проверьте firewall на портах из `.env`.

## Обновление

Обновить внешние образы и пересобрать ComfyUI:

```bash
./scripts/update-images.sh
./scripts/start.sh
```

Для контролируемой версии ComfyUI задайте `COMFYUI_REF` в `.env` на tag/branch/commit и пересоберите.

## Backup

Минимальный backup:

- `.env`
- `data/comfyui/models`
- `data/comfyui/user`
- `data/comfyui/custom_nodes`
- `data/comfyui/output`
- `data/ollama`
- `data/open-webui`

## Security

ComfyUI и result browser по умолчанию доступны без отдельной авторизации внутри LAN. Не публикуйте эти порты в интернет. Для многопользовательского Open WebUI оставьте `WEBUI_AUTH=true` и задайте admin password через UI или `.env`.

## Resource controls

- CPU/RAM: `COMFY_CPUS`, `COMFY_MEM_LIMIT`, `OLLAMA_CPUS`, `OLLAMA_MEM_LIMIT`.
- GPU selection: `NVIDIA_VISIBLE_DEVICES=0` или `0,1`.
- GPU count reservation: `GPU_COUNT=1` или `all`.
- Ollama parallelism: `OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`.
- ComfyUI VRAM behavior: используйте FP8 модели, меньшие resolutions, native offloading и дополнительные args в `COMFYUI_EXTRA_ARGS`.
