# Model recipes

## LLM

Стартовый набор для RTX 5090:

```bash
./scripts/pull-ollama-models.sh qwen3:14b gemma3:12b deepseek-r1:14b
```

После загрузки откройте Open WebUI и выберите модель в dropdown. История чатов хранится в `data/open-webui`.

## Code agents

Для OpenCode/Cline/Roo/Claude Code используйте отдельный llama.cpp backend:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
./scripts/code-llm.sh smoke
```

Default endpoint: `http://localhost:8080/v1`, model id: `code/gemma4-fast`, key: `local-code-llm`. Подробности и альтернативные профили: `docs/code-agents.md`.

Для управления через браузер:

```bash
./scripts/code-llm-manager.sh start
```

UI доступен на `http://127.0.0.1:8091`; через него можно выгружать модель, переключать профили, скачивать GGUF и добавлять новые coding profiles.

Для GLM 5+ используется отдельный `ik_llama.cpp` engine:

```bash
./scripts/code-llm.sh build-engine ik
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

На RTX 5090 профиль собирается с `IK_LLAMA_CUDA_ARCHITECTURES=120`; default параллелизм сборки `16`, при необходимости меняется через `IK_LLAMA_BUILD_JOBS`.

## Image generation

Быстрый старт:

```bash
./scripts/install-comfy-workflows.sh starter
./scripts/download-comfy-workflow-models.sh flux-schnell
```

В ComfyUI откройте workflow из `local/text-to-image`. Starter-набор содержит FLUX Schnell и Qwen Image. Для истории результатов `Save Image.filename_prefix` уже патчится скриптом установки.

Для realistic/editorial portrait и anime/illustration:

```bash
./scripts/install-comfy-workflows.sh portrait
./scripts/install-comfy-workflows.sh anime
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh portrait
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh anime
```

Эти bundles добавляют Flux2 Klein, Qwen illustration, character sheet, multi-angle reference и portrait relighting workflows.

## Image edit, style transfer, reference editing

```bash
./scripts/download-comfy-workflow-models.sh flux-kontext
./scripts/install-comfy-workflows.sh full
./scripts/download-comfy-workflow-models.sh uso-reference
```

Используйте Flux Kontext, Qwen Image Edit и USO reference workflows. Они покрывают image editing, style reference и subject-consistency задачи. Для face swap/identity transfer используйте только материалы с согласием субъекта; не публикуйте такие workflows в интернет.

Optional consent-only identity workflows:

```bash
./scripts/install-comfy-workflows.sh identity-consent
./scripts/install-comfy-custom-nodes.sh identity-consent
```

Они не входят в `starter`/`full` и требуют отдельного решения о доверии к сторонним custom nodes.

## Video generation

```bash
./scripts/download-comfy-workflow-models.sh wan22-5b
```

В ComfyUI откройте `local/text-to-video/video_wan2_2_5B_ti2v.json`. Начните с небольшого resolution/length, затем увеличивайте под мониторингом GPU memory. Для RTX 5090 можно пробовать 14B workflows из full-набора после проверки 5B.

Для character/motion/video-restyle экспериментов:

```bash
./scripts/install-comfy-workflows.sh video-advanced
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh video-advanced
./scripts/install-comfy-custom-nodes.sh video-advanced
```

`video-advanced` также содержит локальный `wan22-remix-t2v-dynamic` workflow: Wan2.2 Remix-style T2V preset для динамичных коротких видео. Для него нужны дополнительные custom nodes:

```bash
./scripts/install-comfy-custom-nodes.sh wan-remix
```

Для `templates_shane_video_restyle` можно поставить только профиль его зависимостей:

```bash
./scripts/install-comfy-custom-nodes.sh video-restyle
./scripts/compose.sh restart comfyui
```

## Audio/music

```bash
./scripts/download-comfy-workflow-models.sh ace-step-song
```

В ComfyUI откройте ACE-Step template. Для text-to-audio задаются `tags` и `lyrics`; для audio-to-audio загрузите исходный audio в `LoadAudio` и регулируйте `denoise`.

Для ACE-Step 1.5 Turbo и stem separation:

```bash
./scripts/install-comfy-workflows.sh audio
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh audio
```

## Custom nodes

Ставьте custom nodes через ComfyUI Manager в интерфейсе или вручную в `data/comfyui/custom_nodes`. После установки зависимостей перезапустите `comfyui`:

```bash
./scripts/compose.sh restart comfyui
```
