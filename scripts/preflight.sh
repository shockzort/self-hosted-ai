#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

ALLOW_CPU_ONLY="${ALLOW_CPU_ONLY:-0}"
failures=0

ok() {
  printf '[ok] %s\n' "$1"
}

warn() {
  printf '[warn] %s\n' "$1" >&2
}

fail() {
  printf '[fail] %s\n' "$1" >&2
  failures=$((failures + 1))
}

if command -v docker >/dev/null 2>&1; then
  ok "$(docker --version)"
else
  fail "docker is not installed"
fi

if docker compose version >/tmp/self-hosted-ai-compose-version.txt 2>&1; then
  ok "$(cat /tmp/self-hosted-ai-compose-version.txt)"
else
  fail "docker compose is not available"
fi

if docker info >/tmp/self-hosted-ai-docker-info.txt 2>&1; then
  ok "Docker daemon is reachable"
else
  fail "Docker daemon is not reachable by this user. Check docker group/rootless Docker or run via sudo."
  sed -n '1,20p' /tmp/self-hosted-ai-docker-info.txt >&2 || true
fi

gpu_ok=0
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/tmp/self-hosted-ai-nvidia-smi.txt 2>&1; then
    ok "nvidia-smi works"
    sed -n '1,12p' /tmp/self-hosted-ai-nvidia-smi.txt
    gpu_ok=1
  else
    if [[ "${ALLOW_CPU_ONLY}" == "1" ]]; then
      warn "nvidia-smi failed; CPU mode is allowed for this check"
    else
      fail "nvidia-smi failed. Install/fix the NVIDIA driver before GPU mode."
    fi
    sed -n '1,20p' /tmp/self-hosted-ai-nvidia-smi.txt >&2 || true
  fi
else
  if [[ "${ALLOW_CPU_ONLY}" == "1" ]]; then
    warn "nvidia-smi not found; CPU mode is allowed for this check"
  else
    fail "nvidia-smi is not installed"
  fi
fi

if [[ "${ALLOW_CPU_ONLY}" == "1" ]]; then
  warn "Skipping Docker GPU runtime validation because ALLOW_CPU_ONLY=1"
elif [[ "${gpu_ok}" == "1" ]] && docker info >/dev/null 2>&1; then
  if ! command -v nvidia-ctk >/dev/null 2>&1; then
    fail "nvidia-ctk is not installed. Run ./scripts/install-nvidia-container-toolkit.sh with sudo-capable user."
  elif docker run --rm --gpus all nvidia/cuda:13.0.2-base-ubuntu24.04 nvidia-smi >/tmp/self-hosted-ai-docker-gpu.txt 2>&1; then
    ok "Docker GPU runtime works"
  else
    fail "Docker GPU runtime failed. Install/configure NVIDIA Container Toolkit."
    sed -n '1,40p' /tmp/self-hosted-ai-docker-gpu.txt >&2 || true
  fi
fi

if [[ "${failures}" -gt 0 ]]; then
  warn "Preflight finished with ${failures} problem(s)"
  exit 1
fi

ok "Preflight passed"
