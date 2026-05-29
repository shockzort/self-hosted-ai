# Operations

## Startup

```bash
cp .env.example .env
./scripts/init.sh
./scripts/preflight.sh
./scripts/start.sh
```

GPU mode uses `compose.yaml + compose.gpu.yaml`. CPU fallback uses `compose.yaml + compose.cpu.yaml`:

```bash
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh
./scripts/start-cpu.sh
```

Before starting the stack, `./scripts/start.sh` installs ComfyUI workflow JSON from `COMFY_WORKFLOW_BUNDLE_ON_START` (`starter` by default). To also download models during startup, set `COMFY_MODEL_BUNDLE_ON_START=starter` in `.env`.

If `COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1`, the ComfyUI entrypoint scans `custom_nodes/*/requirements.txt` before opening the HTTP API. This is useful after installing community nodes, but the first start can be slow and depends on PyPI/GitHub. The entrypoint logs the active requirements file and caches successful installs by hash for repeated starts of the same container. To temporarily exclude a heavy node, use glob patterns in `COMFYUI_REQUIREMENTS_SKIP`, for example `COMFYUI_REQUIREMENTS_SKIP='custom_nodes/experimental-node/requirements.txt'`.

## Directory moves

The stack uses bind mounts for persistent data. `.env` pins:

- `COMPOSE_PROJECT_NAME=self-hosted-ai`
- `SELF_HOSTED_AI_DATA_DIR=./data`
- `SELF_HOSTED_AI_WORKFLOWS_DIR=./workflows`

Startup scripts resolve relative paths to absolute paths before calling `docker compose`, so new containers mount data from the current repository path. To move the repository:

```bash
cd /old/path/self-hosted-ai
./scripts/compose.sh down

cd /new/path/self-hosted-ai
./scripts/init.sh
./scripts/start.sh
```

Do not run `docker compose down -v` or `./scripts/compose.sh down -v` while you still need models, Open WebUI databases, ComfyUI settings, Grafana data, or generation history. Remove the old directory only after checking that `docker inspect <container>` shows mounts from the new `SELF_HOSTED_AI_DATA_DIR`.

## UI credentials

Grafana:

- URL: `http://<host-ip>:3001`
- login: `GF_SECURITY_ADMIN_USER` from `.env`, `admin` by default
- password: `GF_SECURITY_ADMIN_PASSWORD` from `.env`, `change-me` by default

If the Grafana password changes after `data/grafana/grafana.db` already exists, reset it inside the container:

```bash
./scripts/compose.sh exec grafana grafana-cli admin reset-admin-password '<new-password>'
```

Open WebUI:

- URL: `http://<host-ip>:3000`
- signup is enabled through `OPEN_WEBUI_ENABLE_SIGNUP=true`
- the first registered user becomes admin when the database is empty
- later users receive `DEFAULT_USER_ROLE`, `user` by default

If signup was disabled by an older configuration:

```bash
./scripts/open-webui-enable-signup.sh
```

## Grafana dashboards

Dashboards are provisioned from `monitoring/grafana/dashboards` into the `Inference` folder:

- `Inference Overview`: GPU/VRAM/RAM/container CPU/container memory overview.
- `GPU / DCGM Deep Dive`: temperature, power, SM/memory clocks, PCIe, tensor/DRAM activity.
- `Host & Containers`: scrape health, load, CPU throttling, OOM events, network, filesystem IO.

Regenerate dashboard JSON:

```bash
./scripts/generate-grafana-dashboards.py
./scripts/compose.sh restart grafana
```

The DCGM exporter image is configured in `.env` through `DCGM_EXPORTER_IMAGE` and `DCGM_EXPORTER_TAG`. By default the stack uses the Docker Hub mirror `nvidia/dcgm-exporter:4.5.2-4.8.1-distroless`. `./scripts/start.sh`, `./scripts/update-images.sh`, and `./scripts/compose.sh up|pull|create` automatically try `DCGM_EXPORTER_FALLBACK_IMAGES` when the selected registry does not provide the image.

Tune smoke tests for slow first boots with `SMOKE_COMFY_ATTEMPTS`, `SMOKE_DELAY`, `SMOKE_CURL_TIMEOUT`, and `SMOKE_STATUS_EVERY`.

## LAN access

Find the host address:

```bash
hostname -I
```

Open `http://<host-ip>:8188` for ComfyUI or `http://<host-ip>:3000` for Open WebUI from a phone or another LAN machine. If the UI does not open, check firewall rules for the ports from `.env`.

## Updates

Update external images and rebuild ComfyUI:

```bash
./scripts/update-images.sh
./scripts/start.sh
```

For a pinned ComfyUI version, set `COMFYUI_REF` in `.env` to a tag, branch, or commit and rebuild.

## Backup

Minimum backup set:

- `.env`
- `data/comfyui/models`
- `data/comfyui/user`
- `data/comfyui/custom_nodes`
- `data/comfyui/output`
- `data/ollama`
- `data/open-webui`

## Security

ComfyUI and the result browser are available inside the LAN without separate authentication by default. Do not expose these ports to the internet. For multi-user Open WebUI, keep `WEBUI_AUTH=true` and set the admin password through the UI or `.env`.

## Resource controls

- CPU/RAM: `COMFY_CPUS`, `COMFY_MEM_LIMIT`, `OLLAMA_CPUS`, `OLLAMA_MEM_LIMIT`.
- GPU selection: `NVIDIA_VISIBLE_DEVICES=0` or `0,1`.
- GPU count reservation: `GPU_COUNT=1` or `all`.
- Ollama parallelism: `OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`.
- ComfyUI VRAM behavior: use FP8 models, lower resolutions, native offloading, and additional args in `COMFYUI_EXTRA_ARGS`.
