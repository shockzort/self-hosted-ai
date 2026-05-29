# Agent Project Brief

This repository deploys a local self-hosted AI inference stack with Docker Compose.

Core services:
- ComfyUI for image, video, and audio workflows.
- Ollama + Open WebUI for local LLM chat.
- Optional llama.cpp `code-llm` for OpenAI-compatible coding agents.
- Prometheus, Grafana, cAdvisor, node-exporter, and NVIDIA DCGM exporter for monitoring.
- Filebrowser-based results UI for ComfyUI input/output history.

Primary commands:
- Initialize: `./scripts/init.sh`
- Validate host/GPU: `./scripts/preflight.sh`
- Start GPU stack: `./scripts/start.sh`
- Start CPU stack: `ALLOW_CPU_ONLY=1 ./scripts/preflight.sh` then `./scripts/start-cpu.sh`
- Manual compose wrapper: `./scripts/compose.sh ...`
- Smoke test: `./scripts/smoke-test.sh gpu`
- Start Code LLM separately: `./scripts/code-llm.sh start <profile>`

Persistent data defaults to `./data`; workflow JSON defaults to `./workflows`. Do not use `docker compose down -v` unless model files, Open WebUI data, Grafana state, and generation history may be deleted.

The base stack does not start Code LLM. Use `scripts/code-llm.sh` or `scripts/code-llm-manager.sh` for coding-agent models.

Use `./scripts/compose.sh` instead of raw `docker compose` for repository-aware project name, env file, compose files, and path resolution.
