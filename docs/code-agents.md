# Local Code Agents

Research date: 2026-05-16.

## Conclusion

Local AI-assisted coding should use a separate `llama.cpp` server next to the existing Ollama/Open WebUI stack. Coding agents need OpenAI-compatible `/v1/chat/completions`, stable tool calling, and precise control over `--jinja`, KV cache, Flash Attention, and MoE offload. Ollama is convenient as a general model front door, but `llama-server` provides more control for coding agents.

## Sources

- Habr test for Gemma 4 / Qwen 3.6 / Qwen Coder: https://habr.com/ru/articles/1033808/
- llama.cpp server docs: https://www.mintlify.com/ggml-org/llama.cpp/inference/server
- llama.cpp function calling through `--jinja`: https://www.mintlify.com/ggml-org/llama.cpp/advanced/function-calling
- Gemma 4 MXFP4 GGUF: https://huggingface.co/noctrex/gemma-4-26B-A4B-it-MXFP4_MOE-GGUF
- Qwen3.6 GGUF: https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF
- GLM-5.1 1.673 bpw GGUF: https://huggingface.co/sokann/GLM-5.1-GGUF-1.673bpw
- GLM-5.1 GGUF reference set: https://huggingface.co/bartowski/zai-org_GLM-5.1-GGUF
- Open WebUI OpenAI-compatible env: https://docs.openwebui.com/reference/env-configuration/
- OpenCode custom/OpenAI-compatible providers: https://opencode.ai/docs/providers
- Cline OpenAI-compatible provider: https://docs.cline.bot/provider-config/openai-compatible
- Claude Code LLM gateway requirements: https://code.claude.com/docs/en/llm-gateway

## Model profiles

Profiles live in `config/code-llm-models.tsv` and are applied with:

```bash
./scripts/code-llm.sh list
./scripts/code-llm.sh start gemma4-fast
```

Primary profile: `gemma4-fast`. It follows the practical result from the article: for coding-agent tasks, fast mode follows literal project rules better, and `--jinja` is required for tool calling.

Available profiles:

- `gemma4-fast`: Gemma 4 26B-A4B IT MXFP4 MoE, default for RTX 5090 / 24-32 GB VRAM.
- `gemma4-thinking`: same backend with reasoning enabled.
- `qwen36-fast`: Qwen3.6 35B-A3B with `--reasoning off` and `--reasoning-budget 0`.
- `qwen36-thinking`: Qwen3.6 with reasoning.
- `qwen3-coder-fast`: Qwen3-Coder 30B-A3B Instruct Q4_K_M.
- `qwen3-coder-thinking`: Qwen3-Coder with reasoning.
- `glm5-extreme`: GLM-5.1 1.673 bpw GGUF, a current GLM 5+ profile declared for 128 GiB RAM and 24+ GiB VRAM. It is not the default because the model is 146.840 GiB, uses nearly all host RAM, and requires a separate `ik_llama.cpp` engine.

GLM-5.1 uses `sokann/GLM-5.1-GGUF-1.673bpw`: the model card states 128 GiB system RAM + 24 GiB VRAM, 146.840 GiB size, and recommended flags for 88064 context. Higher-quality GLM-5.1 GGUF variants remain above the practical limit for this machine.

## Model downloads

Profiles can be pre-downloaded to `data/code-llm/models`. After download, `./scripts/code-llm.sh select <profile>` automatically switches from Hugging Face auto-download to the local GGUF file.

```bash
./scripts/code-llm.sh download gemma4-fast
./scripts/code-llm.sh download qwen36-fast
./scripts/code-llm.sh download qwen3-coder-fast
./scripts/code-llm.sh download glm5-extreme
```

Check the download plan without downloading:

```bash
DRY_RUN=1 ./scripts/code-llm.sh download glm5-extreme
```

For gated models, add `HF_TOKEN` to `.env`. The GLM-5.1 profile requires at least 180 GiB of free disk space according to the script check, leaving room for cache and temporary files.

## GLM 5+ engine

The standard `ghcr.io/ggml-org/llama.cpp:server-cuda` image works for Gemma/Qwen profiles, but GLM-5.1 needs the additional flags `-mla`, `-khad`, `-mqkv`, `-muge`, `-wgt`, and `-cuda`, which are not present in the verified mainline image. GLM profiles therefore switch compose to the local image `self-hosted-ai-ik-llama.cpp:cuda`.

Build it:

```bash
./scripts/code-llm.sh build-engine ik
```

The verified RTX 5090 setup uses:

```text
IK_LLAMA_CUDA_ARCHITECTURES=120
IK_LLAMA_DEFAULT_BUILD_JOBS=16
```

Architecture `120` is required for Blackwell/RTX 5090. On another NVIDIA GPU, set the appropriate value, for example `89` for Ada, `86` for Ampere consumer, `80` for A100, or `75` for Turing. Excessive build parallelism can crash `nvcc` on CUDA 12.8 + `ik_llama.cpp`; the default is therefore fixed at `16`, not `8`, and can be raised with `IK_LLAMA_BUILD_JOBS` when the toolchain is stable.

Run GLM after building the engine and downloading the model:

```bash
./scripts/code-llm.sh download glm5-extreme
./scripts/code-llm.sh start glm5-extreme
```

## API

After startup:

| Endpoint | URL |
| --- | --- |
| llama.cpp Web UI | `http://localhost:8080` |
| OpenAI-compatible API | `http://localhost:8080/v1` |
| Chat completions | `http://localhost:8080/v1/chat/completions` |
| Models | `http://localhost:8080/v1/models` |
| Open WebUI | `http://localhost:3000` |
| Code LLM Manager | `http://127.0.0.1:8091` |

The default local API key is a placeholder: `local-code-llm`. To require a real bearer token on `llama-server`, set matching values:

```bash
CODE_LLM_API_KEY=local-secret
OPEN_WEBUI_OPENAI_API_KEYS=local-secret
```

## Open WebUI

The `compose.code-llm.yaml` overlay adds an external OpenAI-compatible backend to Open WebUI:

```text
OPENAI_API_BASE_URLS=http://code-llm:8080/v1
OPENAI_API_KEYS=local-code-llm
DEFAULT_MODELS=code/gemma4-fast
```

If Open WebUI has already run and PersistentConfig kept old Connections, add the backend manually in Admin Settings -> Connections -> OpenAI:

- URL: `http://code-llm:8080/v1`
- Key: `local-code-llm`
- Model filter: active alias, for example `code/gemma4-fast`

## Manager UI

For day-to-day coding backend management, use the local manager UI:

```bash
./scripts/code-llm-manager.sh start
```

Open `http://127.0.0.1:8091`. The UI shows the active profile, `code-llm` and Open WebUI container state, RAM, VRAM, GGUF disk usage, local file availability, recent jobs, and `llama-server` logs.

Available operations:

- `Unload`: stop only `code-llm` and release RAM/VRAM.
- `Start`: start the active profile.
- `Switch`: select a profile, recreate `llama-server`, and run the smoke test.
- `Download`: download GGUF for a profile.
- `Dry run`: check the download plan without downloading.
- `Add or update model`: add a new entry to `config/code-llm-models.tsv` and `config/code-llm-downloads.tsv`.

The UI runs in a separate container with access to the Docker socket and the repository because it must execute `scripts/code-llm.sh`, inspect containers, and read `nvidia-smi`. By default the port is bound only to `127.0.0.1` and has no authentication. For LAN access, set `CODE_LLM_MANAGER_BIND=0.0.0.0` only on a trusted network.

New models are added as llama.cpp profiles. For regular Gemma/Qwen/Qwen-Coder models, HF repo/file and alias are enough. For GLM 5+, use an id with the `glm5-` prefix: `scripts/code-llm.sh` will then automatically select the `ik_llama.cpp` image and GLM tensor placement.

## Clients

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

Claude Code requires an Anthropic Messages gateway (`/v1/messages` and `/v1/messages/count_tokens`). llama.cpp declares Anthropic Messages compatibility, but this path must be verified with the exact Claude Code version in use. For OpenCode/Cline/Roo, the primary and more predictable path is OpenAI-compatible `/v1`.

## Verification

```bash
./scripts/code-llm.sh smoke
```

The smoke test checks:

- `/health`
- `/v1/models`
- short `/v1/chat/completions`
- forced tool-call request
- `http://code-llm:8080/v1` reachability from the Open WebUI container

To fail hard on the tool-call check:

```bash
STRICT_TOOL_SMOKE=1 ./scripts/code-llm.sh smoke
```
