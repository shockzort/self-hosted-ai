#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

MANIFEST="${MANIFEST:-config/comfy-models.tsv}"
MODEL_ROOT="${COMFY_MODEL_ROOT:-${SELF_HOSTED_AI_DATA_DIR}/comfyui/models}"

usage() {
  cat <<USAGE
Usage:
  $0 list
  $0 <preset>

Examples:
  $0 flux-schnell
  $0 wan22-5b
  $0 ace-step-v1

Set HF_TOKEN in .env or environment for gated Hugging Face models.
USAGE
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

if [[ "${1}" == "list" ]]; then
  awk -F '\t' 'NF >= 4 && $1 !~ /^#/ { print $1 }' "${MANIFEST}" | sort -u
  exit 0
fi

preset="$1"
matches=0
mkdir -p "${MODEL_ROOT}"

while IFS=$'\t' read -r row_preset target_subdir filename url notes; do
  [[ "${row_preset}" =~ ^#.*$ || -z "${row_preset}" ]] && continue
  [[ "${row_preset}" == "${preset}" ]] || continue

  matches=$((matches + 1))
  target_dir="${MODEL_ROOT}/${target_subdir}"
  target_path="${target_dir}/${filename}"
  mkdir -p "${target_dir}"

  if [[ -f "${target_path}" && "${FORCE:-0}" != "1" ]]; then
    echo "Already exists: ${target_path}"
    continue
  fi

  echo "Downloading ${filename}"
  [[ -n "${notes:-}" ]] && echo "  ${notes}"

  curl_args=(-fL --retry 5 --retry-delay 3 -C - -o "${target_path}")
  if [[ -n "${HF_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi

  curl "${curl_args[@]}" "${url}"
done < "${MANIFEST}"

if [[ "${matches}" -eq 0 ]]; then
  echo "Unknown preset: ${preset}" >&2
  echo "Available presets:" >&2
  "$0" list >&2
  exit 1
fi
