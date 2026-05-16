# Research notes

Дата исследования: 2026-05-10.

Дополнение по локальным кодовым агентам: 2026-05-16.

## Выбранная архитектура

Базовый UI выбран как ComfyUI: он поддерживает graph/node workflows и официальные template workflows для image, video и audio. Для LLM выбран отдельный контур Ollama + Open WebUI, потому что Ollama официально запускается в Docker на Linux с NVIDIA GPU, а Open WebUI дает браузерный интерфейс, историю чатов и доступ из LAN.

## Инфраструктурные выводы

- ComfyUI docs рекомендуют для NVIDIA актуальный PyTorch CUDA 13.0 (`cu130`) и отмечают, что Python 3.13 хорошо поддержан, а Python 3.12 остается хорошим fallback для custom nodes: https://docs.comfy.org/installation/system_requirements
- Docker Compose GPU доступ задается через `deploy.resources.reservations.devices`, где `capabilities: [gpu]` обязателен, а `count` и `device_ids` взаимоисключающие: https://docs.docker.com/compose/how-tos/gpu-support/
- NVIDIA Container Toolkit требует установленного NVIDIA driver, затем `nvidia-ctk runtime configure --runtime=docker` и перезапуск Docker: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.17.8/install-guide.html
- Ollama официально поддерживает Docker на Linux с NVIDIA GPU через `--gpus=all`: https://docs.ollama.com/docker
- Open WebUI работает как self-hosted web UI, поддерживает Ollama/OpenAI-compatible APIs и Docker quick start: https://docs.openwebui.com/

## Модели и workflows

- Официальный репозиторий ComfyUI workflow templates содержит JSON workflows для Flux, Qwen Image, Wan2.2, ACE-Step и других пайплайнов; `scripts/install-comfy-workflows.sh` ставит отобранные workflows из него: https://github.com/Comfy-Org/workflow_templates
- Reddit-поиск по r/comfyui показал практический спрос на Wan2.2 production/video workflows, character consistency, Flux/Qwen reference editing, ACE-Step 1.5, audio mastering/stem separation, Music Tools и consent-only identity transfer workflows. В manifests добавлены только workflows/custom nodes с публичным JSON/source URL; workflows, целенаправленно заточенные под explicit sexual content, не добавлялись.
- Text-to-image: ComfyUI Flux.1 guide описывает Flux.1 Dev/Schnell, FP8 варианты и места размещения `clip_l`, `t5xxl`, `ae` и diffusion models: https://docs.comfy.org/tutorials/flux/flux-1-text-to-image
- Image edit/style transfer: Flux.1 Kontext Dev поддержан native workflow в ComfyUI; guide указывает `flux1-dev-kontext_fp8_scaled.safetensors`, `clip_l`, `t5xxl` и `ae`: https://docs.comfy.org/tutorials/flux/flux-1-kontext-dev
- Reference/style workflows: Flux.1 USO guide описывает subject/style reference сценарии с USO LoRA, projector и SigCLIP vision model: https://docs.comfy.org/tutorials/flux/flux-1-uso
- Text/image-to-video: Wan2.2 official workflow включает 5B hybrid model, который должен помещаться примерно в 8GB VRAM с ComfyUI native offloading, и 14B T2V/I2V варианты для более тяжелого запуска: https://docs.comfy.org/tutorials/video/wan/wan2_2
- Audio/music: ACE-Step native example описывает text-to-audio и audio-to-audio workflows, `ace_step_v1_3.5b.safetensors`, tags/lyrics prompts и Apache-2.0 лицензию проекта: https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1
- ACE-Step 1.5 docs описывают AIO/split workflows, turbo model, 50+ language support and RTX 5090 performance expectations: https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5
- Stable Audio Open 1.0 остается полезным open text-to-audio вариантом, но модель требует принятия условий и имеет Stability AI Community License: https://huggingface.co/stabilityai/stable-audio-open-1.0

## Мониторинг

- cAdvisor экспортирует Docker container metrics в Prometheus-compatible формате: https://prometheus.io/docs/guides/cadvisor/
- NVIDIA DCGM Exporter предоставляет GPU metrics через `/metrics` для Prometheus: https://docs.nvidia.com/datacenter/dcgm/latest/gpu-telemetry/dcgm-exporter.html

## Практический вывод

Для RTX 5090/128GB RAM разумный стартовый набор: Flux Schnell/Dev FP8 для image, Flux Kontext для editing/style workflows, Wan2.2 5B для первого video workflow, ACE-Step v1 для audio/music, и Ollama модели уровня `qwen3:14b`, `gemma3:12b`, `deepseek-r1:14b`. Более тяжелые 14B video workflows и LLM 30B+ стоит включать после проверки VRAM и температуры под мониторингом.

## Локальные кодовые агенты

- Для OpenCode/Cline/Roo Code и похожих клиентов нужен OpenAI-compatible `/v1/chat/completions` backend; Claude Code дополнительно требует gateway с Anthropic Messages `/v1/messages`: https://code.claude.com/docs/en/llm-gateway
- llama.cpp `llama-server` предоставляет OpenAI-compatible endpoints, web UI, metrics и function/tool calling; для tool calling нужен `--jinja`: https://www.mintlify.com/ggml-org/llama.cpp/inference/server и https://www.mintlify.com/ggml-org/llama.cpp/advanced/function-calling
- Habr-тест от 2026-05-11 сравнил Gemma 4 26B-A4B, Qwen 3.6 35B-A3B и Qwen3-Coder 30B-A3B на агентских coding задачах и показал, что fast-режим Gemma 4 лучше всего следовал проектным правилам; использованные параметры перенесены в `config/code-llm-models.tsv`: https://habr.com/ru/articles/1033808/
- GLM 5+ добавлен как отдельный тяжелый профиль `glm5-extreme` на базе GLM-5.1 1.673 bpw GGUF: https://huggingface.co/sokann/GLM-5.1-GGUF-1.673bpw. Карточка модели указывает 128 GiB system RAM + 24 GiB VRAM, размер 146.840 GiB и рекомендуемые флаги для 88064 context. Для ориентира по другим GLM-5.1 GGUF сборкам использован reference set: https://huggingface.co/bartowski/zai-org_GLM-5.1-GGUF
- Для GLM-5.1 mainline `llama.cpp:server-cuda` недостаточен: в проверенном образе нет `-mla`, `-khad`, `-mqkv`, `-muge`, `-wgt`. Поэтому добавлен локальный `ik_llama.cpp` engine. На RTX 5090 он собирается с `IK_LLAMA_CUDA_ARCHITECTURES=120`; `IK_LLAMA_DEFAULT_BUILD_JOBS=16` выбран после проверки, потому что `-j32` ронял `nvcc`, а `-j8` избыточно консервативен для этой машины.
- Для Open WebUI внешний OpenAI-compatible backend задается через `OPENAI_API_BASE_URLS` и `OPENAI_API_KEYS`; из-за PersistentConfig уже запущенную базу иногда нужно поправить в Admin Settings -> Connections: https://docs.openwebui.com/reference/env-configuration/
- OpenCode поддерживает кастомного OpenAI-compatible провайдера через `@ai-sdk/openai-compatible` и `options.baseURL`; пример лежит в `config/code-agents/opencode.json`: https://opencode.ai/docs/providers
