# Troubleshooting

## Missing `sageattention`

If a Wan/KJNodes workflow fails with `No module named 'sageattention'`, check `.env`:

```bash
COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1
COMFYUI_EXTRA_PIP_PACKAGES=sageattention
```

Then rebuild and recreate ComfyUI:

```bash
./scripts/compose.sh up -d --build --force-recreate comfyui
```

## `nvidia-smi` failed

GPU mode cannot work until the host driver responds. Check:

```bash
nvidia-smi
sudo systemctl status nvidia-persistenced
```

After fixing the driver, install NVIDIA Container Toolkit and run:

```bash
sudo ./scripts/install-nvidia-container-toolkit.sh
```

## Docker permission denied

If `docker info` reports permission denied for `/var/run/docker.sock`, add the user to the `docker` group and log in again:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

Alternatively, use rootless Docker or sudo according to your access policy.

## Hugging Face 401/403

For gated models:

1. Open the model page on Hugging Face.
2. Accept the license.
3. Create a token.
4. Write `HF_TOKEN=...` to `.env`.
5. Repeat `./scripts/download-comfy-models.sh <preset>`.

## Out of memory

Lower resolution, frame count, and batch size. Use FP8 weights, enable offloading, and reduce `OLLAMA_NUM_PARALLEL` and `OLLAMA_MAX_LOADED_MODELS`. For ComfyUI, add low-vram args to `COMFYUI_EXTRA_ARGS`.

## Phone cannot open the UI

Check that the phone is on the same network, use the host IP instead of `localhost`, and open the firewall ports from `.env`.

## Grafana does not show GPU data

DCGM exporter does not run in CPU mode. In GPU mode, check:

```bash
./scripts/compose.sh ps dcgm-exporter
curl http://localhost:9400/metrics
```

## DCGM exporter pull fails with `Incorrect Repository Format`

On some Docker/registry combinations, pulls from `nvcr.io/nvidia/k8s/dcgm-exporter` can download layers and then fail with `error from registry: Incorrect Repository Format`. Use the Docker Hub mirror:

```bash
DCGM_EXPORTER_IMAGE=nvidia/dcgm-exporter
DCGM_EXPORTER_TAG=4.5.2-4.8.1-distroless
```

By default, `./scripts/start.sh` and `./scripts/update-images.sh` already try fallback images from `DCGM_EXPORTER_FALLBACK_IMAGES`.

## ComfyUI does not pass smoke-test for a long time

If `./scripts/start.sh` waits for `ComfyUI is reachable` for a long time, check:

```bash
docker logs --tail 120 self-hosted-ai-comfyui-1
```

A common cause is `COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1` with community nodes already installed in `data/comfyui/custom_nodes`. In this mode the entrypoint installs every node's `requirements.txt` before starting the HTTP API. Heavy nodes can download large wheels or build packages from source.

Options:

```bash
COMFYUI_INSTALL_EXTRA_REQUIREMENTS=0 ./scripts/start.sh
COMFYUI_REQUIREMENTS_SKIP='custom_nodes/problem-node/requirements.txt' ./scripts/start.sh
SMOKE_COMFY_ATTEMPTS=600 ./scripts/start.sh
```
