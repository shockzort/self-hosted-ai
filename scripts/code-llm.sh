#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROFILE_FILE="${ROOT_DIR}/config/code-llm-models.tsv"

usage() {
  cat <<USAGE
Usage: $0 <command> [args]

Commands:
  list                         List available code LLM profiles
  select <profile>             Persist a profile into .env
  current                      Show selected .env values
  download [profile|all]       Download GGUF model files for a profile
  build-engine ik              Build the optional ik_llama.cpp engine image
  start [profile]              Start code-llm and re-create Open WebUI wiring
  switch <profile>             Switch code-llm to another profile
  stop                         Stop only code-llm
  unload                       Alias for stop
  restart [profile]            Restart code-llm, optionally selecting profile first
  ps                           Show compose status for the code LLM stack
  logs                         Follow code-llm logs
  smoke                        Run API and Open WebUI reachability checks

Environment:
  MODE=gpu|cpu                 Default: gpu
USAGE
}

shell_quote() {
  local value="$1"
  printf "'"
  printf '%s' "${value}" | sed "s/'/'\\\\''/g"
  printf "'"
}

set_env() {
  local key="$1"
  local value="$2"
  local quoted escaped
  quoted="$(shell_quote "${value}")"
  escaped="${quoted//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//#/\\#}"
  if grep -q "^${key}=" "${ROOT_DIR}/.env"; then
    sed -i "s#^${key}=.*#${key}=${escaped}#" "${ROOT_DIR}/.env"
  else
    printf '%s=%s\n' "${key}" "${quoted}" >> "${ROOT_DIR}/.env"
  fi
}

row_for_profile() {
  local profile="$1"
  awk -F '\t' -v profile="${profile}" '($0 !~ /^#/ && $1 == profile) { print; found=1 } END { exit(found ? 0 : 1) }' "${PROFILE_FILE}"
}

list_profiles() {
  awk -F '\t' '
    $0 !~ /^#/ && NF {
      printf "%-22s %s\n", $1, $2
    }
  ' "${PROFILE_FILE}"
}

profile_model_dir() {
  case "$1" in
    gemma4-*) printf 'gemma4\n' ;;
    qwen36-*) printf 'qwen36\n' ;;
    qwen3-coder-*) printf 'qwen3-coder\n' ;;
    glm5-*) printf 'glm5\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

local_model_path_for_profile() {
  local profile="$1"
  local hf_file="$2"
  local subdir host_path
  [[ -n "${hf_file}" ]] || return 0
  subdir="$(profile_model_dir "${profile}")"
  host_path="${SELF_HOSTED_AI_DATA_DIR}/code-llm/models/${subdir}/${hf_file}"
  if [[ -f "${host_path}" ]]; then
    printf '/models/%s/%s\n' "${subdir}" "${hf_file}"
  fi
}

select_engine_for_profile() {
  local profile="$1"
  case "${profile}" in
    glm5-*)
      set_env CODE_LLM_GPU_IMAGE "${CODE_LLM_IK_GPU_IMAGE:-self-hosted-ai-ik-llama.cpp:cuda}"
      set_env CODE_LLM_CPU_IMAGE "${CODE_LLM_IK_CPU_IMAGE:-self-hosted-ai-ik-llama.cpp:cpu}"
      set_env CODE_LLM_OVERRIDE_TENSORS '\.(76|77)\.ffn_down_exps=CUDA0;\.(74|75|76|77)\.ffn_(up|gate)_exps=CUDA0;exps=CPU'
      set_env CODE_LLM_CACHE_RAM "0"
      set_env CODE_LLM_MEM_LIMIT "132g"
      set_env CODE_LLM_SHM_SIZE "16g"
      ;;
    *)
      set_env CODE_LLM_GPU_IMAGE "${CODE_LLM_MAINLINE_GPU_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda}"
      set_env CODE_LLM_CPU_IMAGE "${CODE_LLM_MAINLINE_CPU_IMAGE:-ghcr.io/ggml-org/llama.cpp:server}"
      set_env CODE_LLM_OVERRIDE_TENSORS ""
      set_env CODE_LLM_CACHE_RAM ""
      set_env CODE_LLM_MEM_LIMIT "${CODE_LLM_DEFAULT_MEM_LIMIT:-96g}"
      set_env CODE_LLM_SHM_SIZE "${CODE_LLM_DEFAULT_SHM_SIZE:-8g}"
      ;;
  esac
}

select_profile() {
  local profile="$1"
  local row
  if ! row="$(row_for_profile "${profile}")"; then
    printf 'Unknown profile: %s\n\nAvailable profiles:\n' "${profile}" >&2
    list_profiles >&2
    exit 1
  fi

  local id description hf_repo hf_file alias ctx_size n_gpu_layers n_cpu_moe batch_size ubatch_size parallel reasoning reasoning_budget temp top_p top_k min_p presence_penalty repeat_penalty no_mmap flash_attn cache_type_k cache_type_v extra_args
  local parsed_row
  parsed_row="${row//$'\t'/$'\037'}"
  IFS=$'\037' read -r id description hf_repo hf_file alias ctx_size n_gpu_layers n_cpu_moe batch_size ubatch_size parallel reasoning reasoning_budget temp top_p top_k min_p presence_penalty repeat_penalty no_mmap flash_attn cache_type_k cache_type_v extra_args <<<"${parsed_row}"
  local local_model
  local_model="$(local_model_path_for_profile "${id}" "${hf_file}")"

  set_env CODE_LLM_PROFILE "${id}"
  set_env CODE_LLM_HF_REPO "${hf_repo}"
  set_env CODE_LLM_HF_FILE "${hf_file}"
  set_env CODE_LLM_MODEL "${local_model}"
  set_env CODE_LLM_ALIAS "${alias}"
  set_env CODE_LLM_CTX_SIZE "${ctx_size}"
  set_env CODE_LLM_N_GPU_LAYERS "${n_gpu_layers}"
  set_env CODE_LLM_N_CPU_MOE "${n_cpu_moe}"
  set_env CODE_LLM_BATCH_SIZE "${batch_size}"
  set_env CODE_LLM_UBATCH_SIZE "${ubatch_size}"
  set_env CODE_LLM_PARALLEL "${parallel}"
  set_env CODE_LLM_REASONING "${reasoning}"
  set_env CODE_LLM_REASONING_BUDGET "${reasoning_budget}"
  set_env CODE_LLM_TEMP "${temp}"
  set_env CODE_LLM_TOP_P "${top_p}"
  set_env CODE_LLM_TOP_K "${top_k}"
  set_env CODE_LLM_MIN_P "${min_p}"
  set_env CODE_LLM_PRESENCE_PENALTY "${presence_penalty}"
  set_env CODE_LLM_REPEAT_PENALTY "${repeat_penalty}"
  set_env CODE_LLM_NO_MMAP "${no_mmap}"
  set_env CODE_LLM_FLASH_ATTN "${flash_attn}"
  set_env CODE_LLM_CACHE_TYPE_K "${cache_type_k}"
  set_env CODE_LLM_CACHE_TYPE_V "${cache_type_v}"
  set_env CODE_LLM_EXTRA_ARGS "${extra_args}"
  select_engine_for_profile "${id}"
  set_env OPEN_WEBUI_DEFAULT_MODELS "${alias}"

  printf 'Selected %s: %s\n' "${id}" "${description}"
  if [[ -n "${local_model}" ]]; then
    printf 'Using downloaded model file: %s\n' "${local_model}"
  fi
}

load_env() {
  "${SCRIPT_DIR}/init.sh" >/dev/null
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/env.sh"
}

code_compose_files() {
  local mode="${MODE:-gpu}"
  if [[ "${mode}" == "cpu" ]]; then
    printf '%s\n' "${COMPOSE_CPU_FILES[@]}" -f compose.code-llm.yaml -f compose.code-llm.cpu.yaml
  else
    printf '%s\n' "${COMPOSE_GPU_FILES[@]}" -f compose.code-llm.yaml -f compose.code-llm.gpu.yaml
  fi
}

compose() {
  local compose_files=()
  mapfile -t compose_files < <(code_compose_files)
  docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" "$@"
}

show_current() {
  load_env
  printf 'MODE=%s\n' "${MODE:-gpu}"
  printf 'CODE_LLM_PROFILE=%s\n' "${CODE_LLM_PROFILE:-gemma4-fast}"
  printf 'CODE_LLM_ALIAS=%s\n' "${CODE_LLM_ALIAS:-code/gemma4-fast}"
  printf 'CODE_LLM_HF_REPO=%s\n' "${CODE_LLM_HF_REPO:-noctrex/gemma-4-26B-A4B-it-MXFP4_MOE-GGUF:MXFP4_MOE}"
  printf 'CODE_LLM_HF_FILE=%s\n' "${CODE_LLM_HF_FILE:-}"
  printf 'CODE_LLM_MODEL=%s\n' "${CODE_LLM_MODEL:-}"
  printf 'CODE_LLM_GPU_IMAGE=%s\n' "${CODE_LLM_GPU_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda}"
  printf 'CODE_LLM_PORT=%s\n' "${CODE_LLM_PORT:-8080}"
  printf 'CODE_LLM_CTX_SIZE=%s\n' "${CODE_LLM_CTX_SIZE:-32768}"
  printf 'CODE_LLM_N_GPU_LAYERS=%s\n' "${CODE_LLM_N_GPU_LAYERS:-999}"
  printf 'CODE_LLM_N_CPU_MOE=%s\n' "${CODE_LLM_N_CPU_MOE:-}"
}

command="${1:-}"
case "${command}" in
  list)
    list_profiles
    ;;
  select)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_env
    select_profile "$2"
    ;;
  current)
    show_current
    ;;
  download)
    exec "${SCRIPT_DIR}/download-code-llm-models.sh" "${@:2}"
    ;;
  build-engine)
    exec "${SCRIPT_DIR}/build-code-llm-engine.sh" "${@:2}"
    ;;
  start)
    load_env
    if [[ $# -ge 2 ]]; then
      select_profile "$2"
      # shellcheck disable=SC1091
      source "${SCRIPT_DIR}/env.sh"
    fi
    compose up -d code-llm open-webui
    "${SCRIPT_DIR}/code-llm-smoke-test.sh"
    ;;
  stop)
    load_env
    compose stop code-llm
    ;;
  unload)
    load_env
    compose stop code-llm
    ;;
  switch)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    load_env
    select_profile "$2"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/env.sh"
    compose up -d --force-recreate code-llm open-webui
    "${SCRIPT_DIR}/code-llm-smoke-test.sh"
    ;;
  restart)
    load_env
    if [[ $# -ge 2 ]]; then
      select_profile "$2"
      # shellcheck disable=SC1091
      source "${SCRIPT_DIR}/env.sh"
    fi
    compose up -d --force-recreate code-llm open-webui
    "${SCRIPT_DIR}/code-llm-smoke-test.sh"
    ;;
  ps)
    load_env
    compose ps code-llm open-webui
    ;;
  logs)
    load_env
    compose logs -f code-llm
    ;;
  smoke)
    "${SCRIPT_DIR}/code-llm-smoke-test.sh"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
