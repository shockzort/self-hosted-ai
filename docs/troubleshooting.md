# Troubleshooting

## Missing `sageattention`

Если Wan/KJNodes workflow падает с `No module named 'sageattention'`, проверьте `.env`:

```bash
COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1
COMFYUI_EXTRA_PIP_PACKAGES=sageattention
```

Затем пересоберите/пересоздайте ComfyUI:

```bash
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml up -d --build --force-recreate comfyui
```

## `nvidia-smi` failed

GPU-режим не заработает, пока host driver не отвечает. Проверьте:

```bash
nvidia-smi
sudo systemctl status nvidia-persistenced
```

После исправления драйвера поставьте NVIDIA Container Toolkit и выполните:

```bash
sudo ./scripts/install-nvidia-container-toolkit.sh
```

## Docker permission denied

Если `docker info` пишет permission denied к `/var/run/docker.sock`, добавьте пользователя в группу `docker` и перелогиньтесь:

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

Либо используйте rootless Docker/sudo согласно вашей политике доступа.

## Hugging Face 401/403

Для gated моделей:

1. Откройте страницу модели в Hugging Face.
2. Примите лицензию.
3. Создайте token.
4. Запишите `HF_TOKEN=...` в `.env`.
5. Повторите `./scripts/download-comfy-models.sh <preset>`.

## Out of memory

Снизьте resolution, frames, batch size, используйте FP8 веса, включайте offloading, уменьшите `OLLAMA_NUM_PARALLEL` и `OLLAMA_MAX_LOADED_MODELS`. Для ComfyUI можно добавить low-vram args в `COMFYUI_EXTRA_ARGS`.

## Телефон не открывает UI

Проверьте, что телефон в той же сети, используйте IP хоста вместо `localhost`, и откройте firewall ports из `.env`.

## Grafana не показывает GPU

В CPU-режиме DCGM exporter не запускается. В GPU-режиме проверьте:

```bash
docker compose --env-file .env -f compose.yaml -f compose.gpu.yaml ps dcgm-exporter
curl http://localhost:9400/metrics
```
