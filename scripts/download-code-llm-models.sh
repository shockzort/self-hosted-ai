#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOWNLOAD_FILE="${ROOT_DIR}/config/code-llm-downloads.tsv"

usage() {
  cat <<USAGE
Usage: $0 [profile|all|list]

Examples:
  $0 gemma4-fast
  $0 glm5-extreme
  DRY_RUN=1 $0 glm5-extreme
  $0 all
USAGE
}

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

list_downloads() {
  awk -F '\t' '
    $0 !~ /^#/ && NF {
      printf "%-22s %-58s %s\n", $1, $2, $3
    }
  ' "${DOWNLOAD_FILE}"
}

row_for_profile() {
  local profile="$1"
  awk -F '\t' -v profile="${profile}" '($0 !~ /^#/ && $1 == profile) { print; found=1 } END { exit(found ? 0 : 1) }' "${DOWNLOAD_FILE}"
}

ensure_disk() {
  local target_dir="$1"
  local min_disk_gib="$2"
  [[ -n "${min_disk_gib}" && "${min_disk_gib}" != "0" ]] || return 0
  mkdir -p "${target_dir}"
  local available_kib available_gib
  available_kib="$(df -Pk "${target_dir}" | awk 'NR == 2 { print $4 }')"
  available_gib=$((available_kib / 1024 / 1024))
  if (( available_gib < min_disk_gib )); then
    printf '[fail] %s has %s GiB free, but %s GiB is required for this download\n' "${target_dir}" "${available_gib}" "${min_disk_gib}" >&2
    exit 1
  fi
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

download_profile() {
  local profile="$1"
  local row
  if ! row="$(row_for_profile "${profile}")"; then
    printf 'Unknown download profile: %s\n\nAvailable profiles:\n' "${profile}" >&2
    list_downloads >&2
    exit 1
  fi

  local id description hf_repo include local_dir local_file min_disk_gib
  local parsed_row
  parsed_row="${row//$'\t'/$'\037'}"
  IFS=$'\037' read -r id description hf_repo include local_dir local_file min_disk_gib <<<"${parsed_row}"

  local target_dir="${SELF_HOSTED_AI_DATA_DIR}/code-llm/models/${local_dir}"
  local cache_dir="${SELF_HOSTED_AI_DATA_DIR}/huggingface"
  ensure_disk "${target_dir}" "${min_disk_gib}"
  mkdir -p "${target_dir}" "${cache_dir}"

  printf '[info] downloading %s from %s\n' "${description}" "${hf_repo}"
  if is_true "${DRY_RUN:-0}"; then
    printf '[dry-run] target directory: %s\n' "${target_dir}"
    printf '[dry-run] huggingface-cli download %s --include %s --local-dir /models/%s\n' "${hf_repo}" "${include}" "${local_dir}"
    return 0
  fi

  docker run --rm \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HF_HOME=/cache/huggingface" \
    -e "HF_HUB_ENABLE_HF_TRANSFER=${HF_HUB_ENABLE_HF_TRANSFER:-1}" \
    -e "HF_HUB_ENABLE_HF_XET=${HF_HUB_ENABLE_HF_XET:-1}" \
    -v "${cache_dir}:/cache/huggingface" \
    -v "${SELF_HOSTED_AI_DATA_DIR}/code-llm/models:/models" \
    python:3.12-slim \
    sh -lc 'python -m pip install -q --no-cache-dir "huggingface_hub[cli,hf_xet]" hf_transfer && huggingface-cli download "$1" --include "$2" --local-dir "$3" --cache-dir /cache/huggingface' \
    download-model "${hf_repo}" "${include}" "/models/${local_dir}"

  if [[ -n "${local_file}" && ! -f "${target_dir}/${local_file}" ]]; then
    printf '[fail] expected downloaded file was not found: %s\n' "${target_dir}/${local_file}" >&2
    exit 1
  fi

  printf '[ok] model files are in %s\n' "${target_dir}"
}

download_all() {
  local profile row key local_dir local_file
  declare -A seen=()
  while IFS=$'\t' read -r profile _ _ _ local_dir local_file _; do
    [[ -n "${profile}" && "${profile}" != \#* ]] || continue
    key="${local_dir}/${local_file}"
    [[ -z "${seen[${key}]:-}" ]] || continue
    seen["${key}"]=1
    download_profile "${profile}"
  done < "${DOWNLOAD_FILE}"
}

case "${1:-${CODE_LLM_PROFILE:-gemma4-fast}}" in
  list)
    list_downloads
    ;;
  all)
    download_all
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    download_profile "${1:-${CODE_LLM_PROFILE:-gemma4-fast}}"
    ;;
esac
