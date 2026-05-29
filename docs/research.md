# Research notes

Research date: 2026-05-10.

Local coding agent addendum: 2026-05-16.

## Selected architecture

The base UI is ComfyUI because it supports graph/node workflows and official template workflows for image, video, and audio. The LLM path uses a separate Ollama + Open WebUI stack because Ollama officially runs in Docker on Linux with NVIDIA GPU support, and Open WebUI provides a browser UI, chat history, and LAN access.

## Infrastructure findings

- ComfyUI docs recommend current PyTorch CUDA 13.0 (`cu130`) for NVIDIA and state that Python 3.13 is well supported, while Python 3.12 remains a good fallback for custom nodes: https://docs.comfy.org/installation/system_requirements
- Docker Compose GPU access is configured through `deploy.resources.reservations.devices`, where `capabilities: [gpu]` is required and `count` and `device_ids` are mutually exclusive: https://docs.docker.com/compose/how-tos/gpu-support/
- NVIDIA Container Toolkit requires an installed NVIDIA driver, then `nvidia-ctk runtime configure --runtime=docker` and a Docker restart: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.17.8/install-guide.html
- Ollama officially supports Docker on Linux with NVIDIA GPU through `--gpus=all`: https://docs.ollama.com/docker
- Open WebUI works as a self-hosted web UI, supports Ollama/OpenAI-compatible APIs, and provides a Docker quick start: https://docs.openwebui.com/

## Models and workflows

- The official ComfyUI workflow templates repository contains JSON workflows for Flux, Qwen Image, Wan2.2, ACE-Step, and other pipelines. `scripts/install-comfy-workflows.sh` installs selected workflows from it: https://github.com/Comfy-Org/workflow_templates
- Reddit research on r/comfyui showed practical demand for Wan2.2 production/video workflows, character consistency, Flux/Qwen reference editing, ACE-Step 1.5, audio mastering/stem separation, Music Tools, and consent-only identity-transfer workflows. The manifests include only workflows/custom nodes with public JSON/source URLs. Workflows intentionally built for explicit sexual content were not added.
- Text-to-image: the ComfyUI Flux.1 guide documents Flux.1 Dev/Schnell, FP8 variants, and placement paths for `clip_l`, `t5xxl`, `ae`, and diffusion models: https://docs.comfy.org/tutorials/flux/flux-1-text-to-image
- Image edit/style transfer: Flux.1 Kontext Dev is supported by a native ComfyUI workflow. The guide specifies `flux1-dev-kontext_fp8_scaled.safetensors`, `clip_l`, `t5xxl`, and `ae`: https://docs.comfy.org/tutorials/flux/flux-1-kontext-dev
- Reference/style workflows: the Flux.1 USO guide documents subject/style reference scenarios with USO LoRA, projector, and SigCLIP vision model: https://docs.comfy.org/tutorials/flux/flux-1-uso
- Text/image-to-video: the official Wan2.2 workflow includes a 5B hybrid model expected to fit in roughly 8 GB VRAM with ComfyUI native offloading, plus 14B T2V/I2V variants for heavier runs: https://docs.comfy.org/tutorials/video/wan/wan2_2
- Audio/music: the ACE-Step native example documents text-to-audio and audio-to-audio workflows, `ace_step_v1_3.5b.safetensors`, tags/lyrics prompts, and the project's Apache-2.0 license: https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1
- ACE-Step 1.5 docs describe AIO/split workflows, the turbo model, 50+ language support, and RTX 5090 performance expectations: https://docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5
- Stable Audio Open 1.0 remains a useful open text-to-audio option, but the model requires terms acceptance and uses the Stability AI Community License: https://huggingface.co/stabilityai/stable-audio-open-1.0

## Monitoring

- cAdvisor exports Docker container metrics in a Prometheus-compatible format: https://prometheus.io/docs/guides/cadvisor/
- NVIDIA DCGM Exporter exposes GPU metrics through `/metrics` for Prometheus: https://docs.nvidia.com/datacenter/dcgm/latest/gpu-telemetry/dcgm-exporter.html

## Practical conclusion

For RTX 5090/128 GB RAM, a reasonable starter set is Flux Schnell/Dev FP8 for images, Flux Kontext for editing/style workflows, Wan2.2 5B for the first video workflow, ACE-Step v1 for audio/music, and Ollama models such as `qwen3:14b`, `gemma3:12b`, and `deepseek-r1:14b`. Enable heavier 14B video workflows and 30B+ LLMs after checking VRAM and temperature under monitoring.

## Local coding agents

- OpenCode/Cline/Roo Code and similar clients need an OpenAI-compatible `/v1/chat/completions` backend. Claude Code additionally requires a gateway with Anthropic Messages `/v1/messages`: https://code.claude.com/docs/en/llm-gateway
- llama.cpp `llama-server` provides OpenAI-compatible endpoints, a web UI, metrics, and function/tool calling. Tool calling requires `--jinja`: https://www.mintlify.com/ggml-org/llama.cpp/inference/server and https://www.mintlify.com/ggml-org/llama.cpp/advanced/function-calling
- The 2026-05-11 Habr test compared Gemma 4 26B-A4B, Qwen 3.6 35B-A3B, and Qwen3-Coder 30B-A3B on agentic coding tasks and found that Gemma 4 fast mode followed project rules best. The tested parameters were transferred to `config/code-llm-models.tsv`: https://habr.com/ru/articles/1033808/
- GLM 5+ was added as a separate heavy `glm5-extreme` profile based on GLM-5.1 1.673 bpw GGUF: https://huggingface.co/sokann/GLM-5.1-GGUF-1.673bpw. The model card states 128 GiB system RAM + 24 GiB VRAM, 146.840 GiB size, and recommended flags for 88064 context. The reference set for other GLM-5.1 GGUF builds is https://huggingface.co/bartowski/zai-org_GLM-5.1-GGUF
- Mainline `llama.cpp:server-cuda` is insufficient for GLM-5.1: the verified image does not include `-mla`, `-khad`, `-mqkv`, `-muge`, and `-wgt`. A local `ik_llama.cpp` engine was added for that reason. On RTX 5090 it builds with `IK_LLAMA_CUDA_ARCHITECTURES=120`; `IK_LLAMA_DEFAULT_BUILD_JOBS=16` was selected after verification because `-j32` crashed `nvcc`, while `-j8` was overly conservative for this machine.
- Open WebUI external OpenAI-compatible backends are configured through `OPENAI_API_BASE_URLS` and `OPENAI_API_KEYS`. With PersistentConfig, an already initialized database can require a manual update in Admin Settings -> Connections: https://docs.openwebui.com/reference/env-configuration/
- OpenCode supports a custom OpenAI-compatible provider through `@ai-sdk/openai-compatible` and `options.baseURL`. An example is in `config/code-agents/opencode.json`: https://opencode.ai/docs/providers
