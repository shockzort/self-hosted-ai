#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<USAGE
Usage: $0 <engine>

Engines:
  ik        Build CUDA ik_llama.cpp image for GLM 5+ GGUF profiles
  ik-cpu    Build CPU ik_llama.cpp image
  all       Build both ik and ik-cpu
USAGE
}

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
default_jobs="${IK_LLAMA_DEFAULT_BUILD_JOBS:-16}"

build_ik_cuda() {
  docker build \
    --target cuda \
    --build-arg "IK_LLAMA_CPP_REF=${IK_LLAMA_CPP_REF:-main}" \
    --build-arg "IK_LLAMA_BUILD_JOBS=${IK_LLAMA_BUILD_JOBS:-${default_jobs}}" \
    --build-arg "IK_LLAMA_CUDA_ARCHITECTURES=${IK_LLAMA_CUDA_ARCHITECTURES:-120}" \
    --build-arg "CUDA_DEVEL_IMAGE=${IK_LLAMA_CUDA_DEVEL_IMAGE:-nvidia/cuda:12.8.1-devel-ubuntu24.04}" \
    --build-arg "CUDA_RUNTIME_IMAGE=${IK_LLAMA_CUDA_RUNTIME_IMAGE:-nvidia/cuda:12.8.1-runtime-ubuntu24.04}" \
    -f docker/code-llm/ik_llama.Dockerfile \
    -t "${CODE_LLM_IK_GPU_IMAGE:-self-hosted-ai-ik-llama.cpp:cuda}" \
    .
}

build_ik_cpu() {
  docker build \
    --target cpu \
    --build-arg "IK_LLAMA_CPP_REF=${IK_LLAMA_CPP_REF:-main}" \
    --build-arg "IK_LLAMA_BUILD_JOBS=${IK_LLAMA_BUILD_JOBS:-${default_jobs}}" \
    --build-arg "UBUNTU_IMAGE=${IK_LLAMA_UBUNTU_IMAGE:-ubuntu:24.04}" \
    -f docker/code-llm/ik_llama.Dockerfile \
    -t "${CODE_LLM_IK_CPU_IMAGE:-self-hosted-ai-ik-llama.cpp:cpu}" \
    .
}

case "${1:-}" in
  ik)
    build_ik_cuda
    ;;
  ik-cpu)
    build_ik_cpu
    ;;
  all)
    build_ik_cuda
    build_ik_cpu
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
