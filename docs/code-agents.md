# Local Code Agents

Дата исследования: 2026-05-16.

## Вывод

Для локального AI-assisted программирования лучше держать отдельный `llama.cpp` server рядом с существующим Ollama/Open WebUI стеком. Причина практическая: агентам нужны OpenAI-compatible `/v1/chat/completions`, стабильный tool calling и точный контроль `--jinja`, KV-cache, Flash Attention и MoE offload. Ollama удобен как универсальная витрина моделей, но `llama-server` дает больше управляемости для кодовых агентов.

## Источники

- Habr-тест Gemma 4 / Qwen 3.6 / Qwen Coder: https://habr.com/ru/articles/1033808/
- llama.cpp server docs: https://www.mintlify.com/ggml-org/llama.cpp/inference/server
- llama.cpp function calling через `--jinja`: https://www.mintlify.com/ggml-org/llama.cpp/advanced/function-calling
- Gemma 4 MXFP4 GGUF: https://huggingface.co/noctrex/gemma-4-26B-A4B-it-MXFP4_MOE-GGUF
- Qwen3.6 GGUF: https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF
- GLM-5.1 1.673 bpw GGUF: https://huggingface.co/sokann/GLM-5.1-GGUF-1.673bpw
- GLM-5.1 GGUF reference set: https://huggingface.co/bartowski/zai-org_GLM-5.1-GGUF
- Open WebUI OpenAI-compatible env: https://docs.openwebui.com/reference/env-configuration/
- OpenCode custom/OpenAI-compatible providers: https://opencode.ai/docs/providers
- Cline OpenAI-compatible provider: https://docs.cline.bot/provider-config/openai-compatible
- Claude Code LLM gateway requirements: https://code.claude.com/docs/en/llm-gateway

## Модельные профили

Профили лежат в `config/code-llm-models.tsv` и применяются через:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
```

Основной профиль: `gemma4-fast`. Он повторяет практический вывод из статьи: для кодовых агентских задач fast-режим лучше следует буквальным правилам проекта, а `--jinja` обязателен для tool calling.

Доступные профили:

- `gemma4-fast`: Gemma 4 26B-A4B IT MXFP4 MoE, default для RTX 5090 / 24-32 GB VRAM.
- `gemma4-thinking`: тот же backend, но reasoning включен.
- `qwen36-fast`: Qwen3.6 35B-A3B с `--reasoning off` и `--reasoning-budget 0`.
- `qwen36-thinking`: Qwen3.6 с reasoning.
- `qwen3-coder-fast`: Qwen3-Coder 30B-A3B Instruct Q4_K_M.
- `qwen3-coder-thinking`: Qwen3-Coder с reasoning.
- `glm5-extreme`: GLM-5.1 1.673 bpw GGUF, свежий GLM 5+ профиль, который заявлен под 128 GiB RAM и 24+ GiB VRAM. Это не default, потому что модель занимает 146.840 GiB, почти весь host RAM и требует отдельного `ik_llama.cpp` engine.

Для GLM-5.1 выбран `sokann/GLM-5.1-GGUF-1.673bpw`: карточка модели указывает 128 GiB system RAM + 24 GiB VRAM, размер 146.840 GiB и рекомендуемые флаги для 88064 context. Более качественные GLM-5.1 GGUF варианты остаются крупнее практического лимита этой машины.

## Загрузка моделей

Профили могут скачиваться заранее в `data/code-llm/models`. После скачивания `./scripts/code-llm.sh select <profile>` автоматически переключится с Hugging Face auto-download на локальный GGUF файл.

```bash
./scripts/code-llm.sh download gemma4-fast
./scripts/code-llm.sh download qwen36-fast
./scripts/code-llm.sh download qwen3-coder-fast
./scripts/code-llm.sh download glm5-extreme
```

Проверить download-план без загрузки:

```bash
DRY_RUN=1 ./scripts/code-llm.sh download glm5-extreme
```

Для gated моделей добавьте `HF_TOKEN` в `.env`. GLM-5.1 профиль требует минимум 180 GiB свободного места по проверке скрипта, чтобы оставить запас на кеш и временные файлы.

## GLM 5+ engine

Обычный `ghcr.io/ggml-org/llama.cpp:server-cuda` подходит для Gemma/Qwen профилей, но для GLM-5.1 нужны дополнительные флаги `-mla`, `-khad`, `-mqkv`, `-muge`, `-wgt` и `-cuda`, которых нет в проверенном mainline образе. Поэтому GLM профили переключают compose на локальный образ `self-hosted-ai-ik-llama.cpp:cuda`.

Собрать его:

```bash
./scripts/code-llm.sh build-engine ik
```

На проверенной RTX 5090 используется:

```text
IK_LLAMA_CUDA_ARCHITECTURES=120
IK_LLAMA_DEFAULT_BUILD_JOBS=16
```

Архитектура `120` нужна для Blackwell/RTX 5090. На другой NVIDIA GPU задайте подходящее значение, например `89` для Ada, `86` для Ampere consumer, `80` для A100, `75` для Turing. Слишком высокий параллелизм сборки может ронять `nvcc` на CUDA 12.8 + `ik_llama.cpp`; поэтому default зафиксирован на `16`, а не на `8`, и при стабильной toolchain его можно поднять через `IK_LLAMA_BUILD_JOBS`.

Запуск GLM после сборки и скачивания:

```bash
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

## API

После запуска:

| Endpoint | URL |
| --- | --- |
| llama.cpp Web UI | `http://localhost:8080` |
| OpenAI-compatible API | `http://localhost:8080/v1` |
| Chat completions | `http://localhost:8080/v1/chat/completions` |
| Models | `http://localhost:8080/v1/models` |
| Open WebUI | `http://localhost:3000` |
| Code LLM Manager | `http://127.0.0.1:8091` |

Локальный API key по умолчанию фиктивный: `local-code-llm`. Если нужен настоящий bearer-token на самом `llama-server`, задайте одинаковые значения:

```bash
CODE_LLM_API_KEY=local-secret
OPEN_WEBUI_OPENAI_API_KEYS=local-secret
```

## Open WebUI

Overlay `compose.code-llm.yaml` добавляет в Open WebUI внешний OpenAI-compatible backend:

```text
OPENAI_API_BASE_URLS=http://code-llm:8080/v1
OPENAI_API_KEYS=local-code-llm
DEFAULT_MODELS=code/gemma4-fast
```

Если Open WebUI уже запускался и PersistentConfig сохранил старые Connections, добавьте backend вручную в Admin Settings -> Connections -> OpenAI:

- URL: `http://code-llm:8080/v1`
- Key: `local-code-llm`
- Model filter: текущий alias, например `code/gemma4-fast`

## Manager UI

Для повседневного управления coding backend есть локальный manager UI:

```bash
./scripts/code-llm-manager.sh start
```

Откройте `http://127.0.0.1:8091`. UI показывает текущий профиль, состояние `code-llm` и Open WebUI контейнеров, RAM, VRAM, место на диске под GGUF, локальное наличие файлов, последние jobs и логи `llama-server`.

Доступные операции:

- `Unload`: остановить только `code-llm` и освободить RAM/VRAM.
- `Start`: поднять текущий профиль.
- `Switch`: выбрать профиль, пересоздать `llama-server`, прогнать smoke test.
- `Download`: скачать GGUF по профилю.
- `Dry run`: проверить download-план без загрузки.
- `Add or update model`: добавить новую запись в `config/code-llm-models.tsv` и `config/code-llm-downloads.tsv`.

UI запускается отдельным контейнером с доступом к Docker socket и репозиторию, потому что ему нужно выполнять `scripts/code-llm.sh`, смотреть контейнеры и читать `nvidia-smi`. По умолчанию порт проброшен только на `127.0.0.1`, без авторизации. Для доступа из LAN задайте `CODE_LLM_MANAGER_BIND=0.0.0.0` только в доверенной сети.

Новые модели добавляются как профиль llama.cpp. Для обычных Gemma/Qwen/Qwen-Coder достаточно HF repo/file и alias. Для GLM 5+ используйте id с префиксом `glm5-`: `scripts/code-llm.sh` тогда автоматически выберет `ik_llama.cpp` image и GLM tensor placement.

## Клиенты

OpenCode:

```bash
cp config/code-agents/opencode.json ./opencode.json
opencode
```

Cline / Roo Code:

- Provider: `OpenAI Compatible`
- Base URL: `http://127.0.0.1:8080/v1`
- API key: `local-code-llm`
- Model ID: `code/gemma4-fast`
- Context window: `32768`

Claude Code:

```bash
source config/code-agents/claude-code.env
claude --model code/gemma4-fast
```

Claude Code требует Anthropic Messages gateway (`/v1/messages` и `/v1/messages/count_tokens`). llama.cpp заявляет Anthropic Messages compatibility, но этот путь нужно проверять именно вашей версией Claude Code; для OpenCode/Cline/Roo основной и более предсказуемый путь - OpenAI-compatible `/v1`.

## Проверка

```bash
./scripts/code-llm.sh smoke
```

Smoke test проверяет:

- `/health`
- `/v1/models`
- короткий `/v1/chat/completions`
- forced tool-call request
- доступность `http://code-llm:8080/v1` из контейнера Open WebUI

Для жесткого падения на tool-call проверке:

```bash
STRICT_TOOL_SMOKE=1 ./scripts/code-llm.sh smoke
```
