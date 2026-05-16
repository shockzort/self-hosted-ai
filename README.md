# Self-hosted image/video/audio inference

Этот репозиторий содержит повторяемый Docker-стек для локального инференса:

- ComfyUI для image/video/audio workflows.
- Ollama + Open WebUI для локальных LLM.
- Отдельный llama.cpp server для локальных кодовых агентов через OpenAI-compatible API.
- Prometheus, Grafana, cAdvisor, node-exporter и NVIDIA DCGM exporter для мониторинга CPU/RAM/GPU.
- Result browser для просмотра истории генераций из локальной сети.

## Быстрый старт

```bash
cp .env.example .env
./scripts/init.sh
./scripts/preflight.sh
./scripts/start.sh
```

Если GPU-драйвер временно недоступен, можно поднять CPU-режим:

```bash
ALLOW_CPU_ONLY=1 ./scripts/preflight.sh
./scripts/start-cpu.sh
```

После запуска:

| Сервис | URL |
| --- | --- |
| ComfyUI | `http://localhost:8188` |
| Open WebUI | `http://localhost:3000` |
| Code LLM API | `http://localhost:8080/v1` |
| Results browser | `http://localhost:8090` |
| Grafana | `http://localhost:3001` |
| Prometheus | `http://localhost:9090` |
| cAdvisor | `http://localhost:8089` |
| Ollama API | `http://localhost:11434` |

Для телефона или другой машины в LAN используйте IP хоста, например `http://192.168.1.20:8188`.

Grafana credentials берутся из `.env`: по умолчанию `admin` / `change-me`.
Open WebUI signup включен по умолчанию; первый зарегистрированный пользователь становится администратором на пустой базе.

Постоянные данные лежат в `SELF_HOSTED_AI_DATA_DIR` из `.env` (`./data` по умолчанию), а Docker Compose проект явно называется `self-hosted-ai`. Для ручных compose-команд используйте `./scripts/compose.sh ...`: он всегда подставляет правильный project name, compose-файлы и пути. Если репозиторий переехал в другой каталог, остановите старый проект командой `./scripts/compose.sh down` без `-v`, перенесите/проверьте `data`, затем запускайте `./scripts/start.sh` из нового каталога.

## Модели

Загрузить LLM в Ollama:

```bash
./scripts/pull-ollama-models.sh
# или явно
./scripts/pull-ollama-models.sh qwen3:14b gemma3:12b deepseek-r1:14b
```

Поднять отдельный llama.cpp API для OpenCode/Cline/Roo/Claude Code:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
```

Локальный GUI для управления coding моделями:

```bash
./scripts/code-llm-manager.sh start
```

Он открывается на `http://127.0.0.1:8091` и умеет показывать RAM/VRAM/disk, текущий профиль, скачивать GGUF, выгружать модель, переключать профили и добавлять новые записи в `config/code-llm-models.tsv`.

Профили Gemma 4 / Qwen 3.6 / Qwen3-Coder / GLM 5+ и клиентские конфиги описаны в `docs/code-agents.md`. Тяжелый GLM профиль требует отдельной сборки engine и явной загрузки модели:

```bash
./scripts/code-llm.sh build-engine ik
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

Посмотреть и загрузить ComfyUI-пресеты:

```bash
./scripts/download-comfy-models.sh list
./scripts/download-comfy-models.sh flux-schnell
./scripts/download-comfy-models.sh wan22-5b
./scripts/download-comfy-models.sh ace-step-v1
```

Для gated Hugging Face моделей сначала примите лицензию на странице модели и добавьте `HF_TOKEN` в `.env`.

Готовые ComfyUI workflows ставятся автоматически при `./scripts/start.sh` из `COMFY_WORKFLOW_BUNDLE_ON_START`. Управлять ими можно явно:

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

## История результатов

ComfyUI пишет результаты в `data/comfyui/output`. Для раздельной истории по алгоритмам задавайте `filename_prefix` в `Save Image/Video/Audio` nodes, например `text-to-image/flux` или `text-to-video/wan22`. Готовые префиксы описаны в `config/output-prefixes.md`.

## Ресурсные лимиты

CPU/RAM лимиты задаются в `.env`: `COMFY_CPUS`, `COMFY_MEM_LIMIT`, `OLLAMA_CPUS`, `OLLAMA_MEM_LIMIT`. GPU выбирается через `NVIDIA_VISIBLE_DEVICES` и `GPU_COUNT`. Жестко ограничить VRAM средствами Docker нельзя, поэтому для VRAM используйте выбор модели, FP8/quantized веса, ComfyUI offloading/low-vram режимы и параметры параллелизма Ollama.

Подробности: `docs/comfyui-usage.md`, `docs/operations.md`, `docs/model-recipes.md`, `docs/research.md`, `docs/troubleshooting.md`.
