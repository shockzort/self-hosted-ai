#!/bin/sh
set -eu

SERVER_BIN=""
for candidate in \
  "$(command -v llama-server 2>/dev/null || true)" \
  /app/llama-server \
  /app/llama.cpp/build/bin/llama-server \
  /app/build/bin/llama-server \
  /app/bin/llama-server \
  /opt/ik_llama.cpp/build/bin/llama-server \
  /usr/local/bin/llama-server \
  /usr/bin/llama-server \
  /llama-server
do
  if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
    SERVER_BIN="${candidate}"
    break
  fi
done

if [ -z "${SERVER_BIN}" ]; then
  echo "llama-server binary was not found in the image" >&2
  exit 127
fi

is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

is_false() {
  case "${1:-}" in
    0|false|FALSE|False|no|NO|No|off|OFF|Off) return 0 ;;
    *) return 1 ;;
  esac
}

on_off_auto() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) printf 'on\n' ;;
    0|false|FALSE|False|no|NO|No|off|OFF|Off) printf 'off\n' ;;
    auto|AUTO|Auto) printf 'auto\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

set -- \
  --host 0.0.0.0 \
  --port "${CODE_LLM_CONTAINER_PORT:-8080}"

if [ -n "${CODE_LLM_MODEL:-}" ]; then
  set -- "$@" --model "${CODE_LLM_MODEL}"
else
  set -- "$@" --hf-repo "${CODE_LLM_HF_REPO:?CODE_LLM_HF_REPO or CODE_LLM_MODEL is required}"
  if [ -n "${CODE_LLM_HF_FILE:-}" ]; then
    set -- "$@" --hf-file "${CODE_LLM_HF_FILE}"
  fi
fi

if [ -n "${CODE_LLM_ALIAS:-}" ]; then
  set -- "$@" --alias "${CODE_LLM_ALIAS}"
fi
if [ -n "${CODE_LLM_CTX_SIZE:-}" ]; then
  set -- "$@" --ctx-size "${CODE_LLM_CTX_SIZE}"
fi
if [ -n "${CODE_LLM_N_GPU_LAYERS:-}" ]; then
  set -- "$@" --n-gpu-layers "${CODE_LLM_N_GPU_LAYERS}"
fi
if [ -n "${CODE_LLM_N_CPU_MOE:-}" ]; then
  set -- "$@" --n-cpu-moe "${CODE_LLM_N_CPU_MOE}"
fi
if [ -n "${CODE_LLM_FLASH_ATTN:-}" ]; then
  set -- "$@" --flash-attn "$(on_off_auto "${CODE_LLM_FLASH_ATTN}")"
fi
if [ -n "${CODE_LLM_CACHE_TYPE_K:-}" ]; then
  set -- "$@" --cache-type-k "${CODE_LLM_CACHE_TYPE_K}"
fi
if [ -n "${CODE_LLM_CACHE_TYPE_V:-}" ]; then
  set -- "$@" --cache-type-v "${CODE_LLM_CACHE_TYPE_V}"
fi
if [ -n "${CODE_LLM_BATCH_SIZE:-}" ]; then
  set -- "$@" --batch-size "${CODE_LLM_BATCH_SIZE}"
fi
if [ -n "${CODE_LLM_UBATCH_SIZE:-}" ]; then
  set -- "$@" --ubatch-size "${CODE_LLM_UBATCH_SIZE}"
fi
if [ -n "${CODE_LLM_PARALLEL:-}" ]; then
  set -- "$@" --parallel "${CODE_LLM_PARALLEL}"
fi
if is_true "${CODE_LLM_JINJA:-1}"; then
  set -- "$@" --jinja
elif is_false "${CODE_LLM_JINJA:-1}"; then
  set -- "$@" --no-jinja
fi
if [ -n "${CODE_LLM_REASONING:-}" ]; then
  set -- "$@" --reasoning "${CODE_LLM_REASONING}"
fi
if [ -n "${CODE_LLM_REASONING_BUDGET:-}" ]; then
  set -- "$@" --reasoning-budget "${CODE_LLM_REASONING_BUDGET}"
fi
if [ -n "${CODE_LLM_TEMP:-}" ]; then
  set -- "$@" --temp "${CODE_LLM_TEMP}"
fi
if [ -n "${CODE_LLM_TOP_P:-}" ]; then
  set -- "$@" --top-p "${CODE_LLM_TOP_P}"
fi
if [ -n "${CODE_LLM_TOP_K:-}" ]; then
  set -- "$@" --top-k "${CODE_LLM_TOP_K}"
fi
if [ -n "${CODE_LLM_MIN_P:-}" ]; then
  set -- "$@" --min-p "${CODE_LLM_MIN_P}"
fi
if [ -n "${CODE_LLM_PRESENCE_PENALTY:-}" ]; then
  set -- "$@" --presence-penalty "${CODE_LLM_PRESENCE_PENALTY}"
fi
if [ -n "${CODE_LLM_REPEAT_PENALTY:-}" ]; then
  set -- "$@" --repeat-penalty "${CODE_LLM_REPEAT_PENALTY}"
fi
if is_true "${CODE_LLM_NO_MMAP:-1}"; then
  set -- "$@" --no-mmap
elif is_false "${CODE_LLM_NO_MMAP:-1}"; then
  set -- "$@" --mmap
fi
if is_true "${CODE_LLM_METRICS:-1}"; then
  set -- "$@" --metrics
fi
if [ -n "${CODE_LLM_API_KEY:-}" ]; then
  set -- "$@" --api-key "${CODE_LLM_API_KEY}"
fi
if [ -n "${CODE_LLM_OVERRIDE_TENSORS:-}" ]; then
  old_ifs="${IFS}"
  IFS=';'
  for tensor_override in ${CODE_LLM_OVERRIDE_TENSORS}; do
    if [ -n "${tensor_override}" ]; then
      set -- "$@" --override-tensor "${tensor_override}"
    fi
  done
  IFS="${old_ifs}"
fi
if [ -n "${CODE_LLM_CACHE_RAM:-}" ]; then
  set -- "$@" --cache-ram "${CODE_LLM_CACHE_RAM}"
fi
if [ -n "${CODE_LLM_EXTRA_ARGS:-}" ]; then
  # Intentional shell word splitting for simple extra flags such as:
  # CODE_LLM_EXTRA_ARGS="--threads 16 --timeout 1200"
  # shellcheck disable=SC2086
  set -- "$@" ${CODE_LLM_EXTRA_ARGS}
fi

echo "Starting llama-server as ${CODE_LLM_ALIAS:-${CODE_LLM_HF_REPO:-${CODE_LLM_MODEL}}}"
exec "${SERVER_BIN}" "$@"
