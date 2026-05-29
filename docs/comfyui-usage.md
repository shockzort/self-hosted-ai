# ComfyUI usage

## Installed workflows

Workflow JSON files are installed from `config/comfy-workflows.tsv` into `workflows/<category>`. This directory is mounted into ComfyUI as `user/default/workflows/local`, so the workflows are available in the workflow browser after startup.

```bash
./scripts/install-comfy-workflows.sh list
./scripts/install-comfy-workflows.sh starter
./scripts/install-comfy-workflows.sh full
```

`starter` installs the practical minimum:

- `flux-schnell`: text-to-image.
- `qwen-image`: second text-to-image pipeline.
- `flux-kontext`: image editing/style edits.
- `qwen-image-edit`: second image-edit pipeline.
- `wan22-5b`: text/image-to-video.
- `ace-step-song`: text-to-audio/music.

`full` adds FLUX Krea, the USO reference workflow, Qwen Image Edit 2511, Wan2.2 14B T2V/I2V/FLF2V, and ACE-Step editing.

Additional thematic bundles:

- `portrait`: realistic/editorial portrait, relighting, multi-angle character references.
- `anime`: illustration/anime-style image workflows.
- `character`: character sheets and multi-angle reference workflows.
- `video-advanced`: Wan2.2 character/motion/video-restyle workflows.
- `reddit`: curated Reddit-inspired workflows that have stable public JSON sources.
- `identity-consent`: optional identity-transfer workflows. Use only with explicit consent from depicted people; this bundle is not installed by `starter` or `full`.

## Models

The model download script reads model metadata from workflow JSON files and places files into the correct ComfyUI directories:

```bash
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh starter
./scripts/download-comfy-workflow-models.sh starter
```

For gated Hugging Face models, accept the model terms in a browser first and pass a token:

```bash
HF_TOKEN=hf_... ./scripts/download-comfy-workflow-models.sh starter
```

Full starter preparation:

```bash
./scripts/bootstrap-inference.sh starter
```

To download models automatically during startup, set this in `.env`:

```bash
COMFY_MODEL_BUNDLE_ON_START=starter
```

By default, startup installs only workflow JSON files. Model downloads are disabled by default because `starter` and `full` bundles take tens of gigabytes, and some files can require a Hugging Face token.

## Custom nodes

Some community workflows require third-party custom nodes. They are not installed automatically because custom nodes execute Python code inside ComfyUI.

```bash
./scripts/install-comfy-custom-nodes.sh list
./scripts/install-comfy-custom-nodes.sh video-advanced
./scripts/install-comfy-custom-nodes.sh video-restyle
./scripts/install-comfy-custom-nodes.sh composition
```

Restart ComfyUI after installation. If a node repository contains `requirements.txt`, enable dependency installation on startup:

```bash
COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1
```

For `templates_shane_video_restyle`, use `video-restyle`: it installs `ComfyUI-WanVideoWrapper`, `ComfyUI-DepthAnythingV2`, and `comfyui_controlnet_aux`. Installing these node packs through the UI can happen at the wrong point in the container lifecycle; after script installation, restart `comfyui`.

## Running inference through the UI

1. Open `http://<host-ip>:8188`.
2. Open a workflow from `local/<category>`.
3. For image/video/audio edit workflows, load input files into `Load Image` or `Load Audio` nodes.
4. Check model loader nodes: the file name must match what `download-comfy-workflow-models.sh` downloaded.
5. Edit prompt, seed, resolution, and frames/length.
6. Click `Queue Prompt`.

Results are written to `data/comfyui/output` and exposed through the results browser at `http://<host-ip>:8090`. The workflow installer patches `Save Image/Video/Audio` nodes so results land in separate subdirectories: `text-to-image`, `text-to-video`, `image-edit`, `style-transfer`, and `audio`.

The system does not install or document workflows built specifically for explicit sexual content. For portraits and characters, use adult-looking, clothed, editorial/fashion/pin-up wording and verify that you have rights to use the source images.

## Automation API

For batch execution through the API, open the workflow in ComfyUI, choose `Save (API Format)`, then send JSON to `POST /prompt`. UI workflows from `workflows/` are convenient for operators, but the ComfyUI API requires a separate API-format JSON.
