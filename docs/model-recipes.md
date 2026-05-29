# Model recipes

## LLM

Starter set for RTX 5090:

```bash
./scripts/pull-ollama-models.sh qwen3:14b gemma3:12b deepseek-r1:14b
```

After downloading, open Open WebUI and select the model in the dropdown. Chat history is stored in `data/open-webui`.

## Code agents

Use the separate llama.cpp backend for OpenCode/Cline/Roo/Claude Code:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
./scripts/code-llm.sh smoke
```

Default endpoint: `http://localhost:8080/v1`, model id: `code/gemma4-fast`, key: `local-code-llm`. Details and alternative profiles: `docs/code-agents.md`.

For browser-based management:

```bash
./scripts/code-llm-manager.sh start
```

The UI is available at `http://127.0.0.1:8091`; it can unload the model, switch profiles, download GGUF files, and add new coding profiles.

GLM 5+ uses a separate `ik_llama.cpp` engine:

```bash
./scripts/code-llm.sh build-engine ik
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

On RTX 5090 the profile builds with `IK_LLAMA_CUDA_ARCHITECTURES=120`; default build parallelism is `16` and can be changed with `IK_LLAMA_BUILD_JOBS`.

## Image generation

Quick start:

```bash
./scripts/install-comfy-workflows.sh starter
./scripts/download-comfy-workflow-models.sh flux-schnell
```

In ComfyUI, open a workflow from `local/text-to-image`. The starter bundle includes FLUX Schnell and Qwen Image. `Save Image.filename_prefix` is already patched by the installer for result history.

For realistic/editorial portraits and anime/illustration:

```bash
./scripts/install-comfy-workflows.sh portrait
./scripts/install-comfy-workflows.sh anime
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh portrait
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh anime
```

These bundles add Flux2 Klein, Qwen illustration, character sheet, multi-angle reference, and portrait relighting workflows.

## Image edit, style transfer, reference editing

```bash
./scripts/download-comfy-workflow-models.sh flux-kontext
./scripts/install-comfy-workflows.sh full
./scripts/download-comfy-workflow-models.sh uso-reference
```

Use Flux Kontext, Qwen Image Edit, and USO reference workflows. They cover image editing, style reference, and subject-consistency tasks. For face swap or identity transfer, use only material with the depicted person's consent; do not publish such workflows to the internet.

Optional consent-only identity workflows:

```bash
./scripts/install-comfy-workflows.sh identity-consent
./scripts/install-comfy-custom-nodes.sh identity-consent
```

They are not included in `starter` or `full` and require a separate trust decision for third-party custom nodes.

## Video generation

```bash
./scripts/download-comfy-workflow-models.sh wan22-5b
```

In ComfyUI, open `local/text-to-video/video_wan2_2_5B_ti2v.json`. Start with a small resolution/length, then increase it while monitoring GPU memory. On RTX 5090, try 14B workflows from the full bundle after validating 5B.

For character/motion/video-restyle experiments:

```bash
./scripts/install-comfy-workflows.sh video-advanced
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh video-advanced
./scripts/install-comfy-custom-nodes.sh video-advanced
```

`video-advanced` also includes the local `wan22-remix-t2v-dynamic` workflow: a Wan2.2 Remix-style T2V preset for dynamic short videos. It needs additional custom nodes:

```bash
./scripts/install-comfy-custom-nodes.sh wan-remix
```

For `templates_shane_video_restyle`, install only its dependency profile:

```bash
./scripts/install-comfy-custom-nodes.sh video-restyle
./scripts/compose.sh restart comfyui
```

## Audio/music

```bash
./scripts/download-comfy-workflow-models.sh ace-step-song
```

In ComfyUI, open the ACE-Step template. For text-to-audio, set `tags` and `lyrics`; for audio-to-audio, load the source audio into `LoadAudio` and tune `denoise`.

For ACE-Step 1.5 Turbo and stem separation:

```bash
./scripts/install-comfy-workflows.sh audio
DRY_RUN=1 ./scripts/download-comfy-workflow-models.sh audio
```

## Custom nodes

Install custom nodes through ComfyUI Manager in the UI or manually into `data/comfyui/custom_nodes`. After dependency installation, restart `comfyui`:

```bash
./scripts/compose.sh restart comfyui
```
