# Self-hosted image/video/audio inference

This repository provides a repeatable Docker stack for local inference:

- ComfyUI for image, video, and audio workflows.
- Ollama + Open WebUI for local LLMs.
- A separate llama.cpp server for local coding agents through an OpenAI-compatible API.
- Prometheus, Grafana, cAdvisor, node-exporter, and NVIDIA DCGM exporter for CPU/RAM/GPU monitoring.
- A result browser for generation history on the local network.

## Quick start

```bash
cp .env.example .env
./scripts/init.sh
./scripts/preflight.sh
./scripts/start.sh
```

If the GPU driver is temporarily unavailable, start the CPU profile:

```bash
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh
./scripts/start-cpu.sh
```

After startup:

| Service | URL |
| --- | --- |
| ComfyUI | `http://localhost:8188` |
| Open WebUI | `http://localhost:3000` |
| Results browser | `http://localhost:8090` |
| Grafana | `http://localhost:3001` |
| Prometheus | `http://localhost:9090` |
| cAdvisor | `http://localhost:8089` |
| Ollama API | `http://localhost:11434` |

For a phone or another machine on the LAN, use the host IP, for example `http://192.168.1.20:8188`.

Grafana credentials come from `.env`: `admin` / `change-me` by default.
Open WebUI signup is enabled by default; the first registered user becomes administrator on an empty database.
For GPU monitoring, DCGM exporter uses Docker Hub (`nvidia/dcgm-exporter`) by default. Startup scripts can try fallback images from `DCGM_EXPORTER_FALLBACK_IMAGES` when the selected registry is unavailable or rejects the image.

Persistent data is stored in `SELF_HOSTED_AI_DATA_DIR` from `.env` (`./data` by default), and the Docker Compose project name is fixed to `self-hosted-ai`. For manual compose commands, use `./scripts/compose.sh ...`: it always injects the correct project name, compose files, and paths. If the repository moves to another directory, stop the old project with `./scripts/compose.sh down` without `-v`, move or verify `data`, then run `./scripts/start.sh` from the new directory.

## Models

Pull LLMs into Ollama:

```bash
./scripts/pull-ollama-models.sh
# or explicitly
./scripts/pull-ollama-models.sh qwen3:14b gemma3:12b deepseek-r1:14b
```

Start the separate llama.cpp API for OpenCode/Cline/Roo/Claude Code:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
```

After the separate Code LLM startup, the API is available at `http://localhost:8080/v1`.

Local GUI for coding model management:

```bash
./scripts/code-llm-manager.sh start
```

It runs at `http://127.0.0.1:8091` and shows RAM/VRAM/disk usage, the active profile, GGUF downloads, model unloads, profile switching, and new entries for `config/code-llm-models.tsv`.

Gemma 4 / Qwen 3.6 / Qwen3-Coder / GLM 5+ profiles and client configs are documented in `docs/code-agents.md`. The heavy GLM profile requires a separate engine build and an explicit model download:

```bash
./scripts/code-llm.sh build-engine ik
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

List and download ComfyUI presets:

```bash
./scripts/download-comfy-models.sh list
./scripts/download-comfy-models.sh flux-schnell
./scripts/download-comfy-models.sh wan22-5b
./scripts/download-comfy-models.sh ace-step-v1
```

For gated Hugging Face models, accept the model license first and add `HF_TOKEN` to `.env`.

Ready-to-use ComfyUI workflows are installed automatically during `./scripts/start.sh` from `COMFY_WORKFLOW_BUNDLE_ON_START`. Manage them explicitly with:

```bash
./scripts/install-comfy-workflows.sh list
./scripts/install-comfy-workflows.sh starter
./scripts/install-comfy-workflows.sh portrait
./scripts/install-comfy-workflows.sh anime
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh starter
./scripts/bootstrap-inference.sh starter
```

Optional community nodes:

```bash
./scripts/install-comfy-custom-nodes.sh list
./scripts/install-comfy-custom-nodes.sh video-advanced
```

If `data/comfyui/custom_nodes` already contains community nodes and `COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1`, the first ComfyUI start can take several minutes: the entrypoint installs those nodes' `requirements.txt` files before opening the HTTP API. Use `COMFYUI_REQUIREMENTS_SKIP` to temporarily skip problematic nodes. Repeated starts of the same container skip unchanged requirements through a hash cache.

## Result history

ComfyUI writes results to `data/comfyui/output`. For per-algorithm history, set `filename_prefix` in `Save Image/Video/Audio` nodes, for example `text-to-image/flux` or `text-to-video/wan22`. Ready prefixes are listed in `config/output-prefixes.md`.

## Resource limits

CPU/RAM limits are configured in `.env`: `COMFY_CPUS`, `COMFY_MEM_LIMIT`, `OLLAMA_CPUS`, `OLLAMA_MEM_LIMIT`. GPU selection uses `NVIDIA_VISIBLE_DEVICES` and `GPU_COUNT`. Docker cannot strictly cap VRAM, so control VRAM through model choice, FP8/quantized weights, ComfyUI offloading/low-vram mode, and Ollama parallelism settings.

Details: `docs/comfyui-usage.md`, `docs/operations.md`, `docs/model-recipes.md`, `docs/research.md`, `docs/troubleshooting.md`.
