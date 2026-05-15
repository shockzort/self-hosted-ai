# ComfyUI usage

## Установленные пайплайны

Workflow JSON ставятся из `config/comfy-workflows.tsv` в `workflows/<category>`. Эта директория смонтирована в ComfyUI как `user/default/workflows/local`, поэтому после запуска они доступны в workflow browser.

```bash
./scripts/install-comfy-workflows.sh list
./scripts/install-comfy-workflows.sh starter
./scripts/install-comfy-workflows.sh full
```

`starter` ставит практический минимум:

- `flux-schnell`: text-to-image.
- `qwen-image`: второй text-to-image пайплайн.
- `flux-kontext`: image editing/style edits.
- `qwen-image-edit`: второй image-edit пайплайн.
- `wan22-5b`: text/image-to-video.
- `ace-step-song`: text-to-audio/music.

`full` добавляет FLUX Krea, USO reference workflow, Qwen Image Edit 2511, Wan2.2 14B T2V/I2V/FLF2V и ACE-Step editing.

Дополнительные тематические bundles:

- `portrait`: realistic/editorial portrait, relighting, multi-angle character references.
- `anime`: illustration/anime-style image workflows.
- `character`: character sheets and multi-angle reference workflows.
- `video-advanced`: Wan2.2 character/motion/video-restyle workflows.
- `reddit`: curated Reddit-inspired workflows that have stable public JSON sources.
- `identity-consent`: optional identity-transfer workflows. Use only with explicit consent from depicted people; this bundle is not installed by `starter` or `full`.

## Модели

Скрипт умеет читать model metadata из workflow JSON и складывать файлы в директории ComfyUI:

```bash
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh starter
./scripts/download-comfy-workflow-models.sh starter
```

Для gated Hugging Face моделей сначала примите условия модели в браузере и укажите токен:

```bash
HF_TOKEN=hf_... ./scripts/download-comfy-workflow-models.sh starter
```

Полная подготовка starter-набора:

```bash
./scripts/bootstrap-inference.sh starter
```

Для автоматической загрузки моделей на старте задайте в `.env`:

```bash
COMFY_MODEL_BUNDLE_ON_START=starter
```

По умолчанию на старте автоматически ставятся только workflow JSON. Загрузка моделей не включена по умолчанию, потому что starter/full наборы занимают десятки гигабайт и часть файлов может требовать Hugging Face token.

## Custom nodes

Некоторые community workflows требуют сторонние custom nodes. Они не ставятся автоматически, потому что custom nodes исполняют Python-код внутри ComfyUI.

```bash
./scripts/install-comfy-custom-nodes.sh list
./scripts/install-comfy-custom-nodes.sh video-advanced
./scripts/install-comfy-custom-nodes.sh video-restyle
./scripts/install-comfy-custom-nodes.sh composition
```

После установки перезапустите ComfyUI. Если node repo содержит `requirements.txt`, можно включить установку зависимостей на старте:

```bash
COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1
```

Для `templates_shane_video_restyle` используйте именно `video-restyle`: он ставит `ComfyUI-WanVideoWrapper`, `ComfyUI-DepthAnythingV2` и `comfyui_controlnet_aux`. Через UI эти node packs могут поставиться в неправильный момент жизненного цикла контейнера; после установки скриптом перезапустите `comfyui`.

## Запуск инференса через UI

1. Откройте `http://<host-ip>:8188`.
2. Откройте workflow из `local/<category>`.
3. Для image/video/audio edit workflows загрузите входные файлы в `Load Image` или `Load Audio` nodes.
4. Проверьте model loader nodes: имя файла должно совпадать с тем, что скачал `download-comfy-workflow-models.sh`.
5. Измените prompt, seed, resolution, frames/length.
6. Нажмите `Queue Prompt`.

Результаты пишутся в `data/comfyui/output` и доступны через Results browser: `http://<host-ip>:8090`. Скрипт установки workflow патчит `Save Image/Video/Audio` nodes так, чтобы результаты попадали в отдельные подпапки: `text-to-image`, `text-to-video`, `image-edit`, `style-transfer`, `audio`.

Система не устанавливает и не документирует workflows, специально предназначенные для откровенного sexual content. Для портретов и персонажей используйте adult-looking, clothed, editorial/fashion/pin-up формулировки и проверяйте право на использование исходных изображений.

## Автоматический API

Для пакетного запуска через API откройте workflow в ComfyUI, выберите `Save (API Format)`, затем отправляйте JSON в `POST /prompt`. UI workflows из `workflows/` удобны для оператора, но ComfyUI API требует отдельный API-format JSON.
