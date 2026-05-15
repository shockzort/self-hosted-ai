#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

MANIFEST="${COMFY_WORKFLOW_MANIFEST:-config/comfy-workflows.tsv}"
WORKFLOW_ROOT="${COMFY_WORKFLOW_ROOT:-${SELF_HOSTED_AI_WORKFLOWS_DIR}}"
MODEL_ROOT="${COMFY_MODEL_ROOT:-${SELF_HOSTED_AI_DATA_DIR}/comfyui/models}"
TARGET="${1:-starter}"

usage() {
  cat <<USAGE
Usage:
  $0 <bundle-or-slug>

Downloads model files declared in installed workflow JSON metadata and places them
under ${MODEL_ROOT}/<directory>/<name>.

Examples:
  $0 starter
  $0 flux-kontext
  $0 all

Set HF_TOKEN in .env or environment for gated Hugging Face models.
Set DRY_RUN=1 to only list files.
USAGE
}

if [[ "${TARGET}" == "" || "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to read workflow model metadata" >&2
  exit 1
fi

contains_bundle() {
  local bundles="$1"
  local needle="$2"
  [[ ",${bundles}," == *",${needle},"* ]]
}

selected_workflows=()
while IFS=$'\t' read -r bundles slug category filename url output_prefix notes; do
  [[ "${bundles}" =~ ^#.*$ || -z "${bundles}" ]] && continue
  if [[ "${TARGET}" != "all" && "${slug}" != "${TARGET}" ]] && ! contains_bundle "${bundles}" "${TARGET}"; then
    continue
  fi
  selected_workflows+=("${WORKFLOW_ROOT}/${category}/${filename}")
done < "${MANIFEST}"

if [[ "${#selected_workflows[@]}" -eq 0 ]]; then
  echo "Unknown workflow bundle or slug: ${TARGET}" >&2
  exit 1
fi

missing=0
for workflow in "${selected_workflows[@]}"; do
  if [[ ! -f "${workflow}" ]]; then
    missing=$((missing + 1))
  fi
done

if [[ "${missing}" -gt 0 ]]; then
  echo "Installing missing workflow JSON files for ${TARGET}"
  ./scripts/install-comfy-workflows.sh "${TARGET}"
fi

model_list="$(mktemp)"
trap 'rm -f "${model_list}"' EXIT

for workflow in "${selected_workflows[@]}"; do
  [[ -f "${workflow}" ]] || continue
  jq -r '
    .. | objects
    | select(has("models"))
    | .models[]?
    | select(.name and .url and .directory)
    | [.directory, .name, .url] | @tsv
  ' "${workflow}" >> "${model_list}"
done

sort -u -o "${model_list}" "${model_list}"

if [[ ! -s "${model_list}" ]]; then
  echo "No model metadata found in selected workflows" >&2
  exit 1
fi

mkdir -p "${MODEL_ROOT}"

while IFS=$'\t' read -r directory name url; do
  [[ -n "${directory}" && -n "${name}" && -n "${url}" ]] || continue

  target_dir="${MODEL_ROOT}/${directory}"
  target_path="${target_dir}/${name}"
  mkdir -p "${target_dir}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s\t%s\n' "${target_path}" "${url}"
    continue
  fi

  if [[ -f "${target_path}" && "${FORCE:-0}" != "1" ]]; then
    echo "Already exists: ${target_path}"
    continue
  fi

  echo "Downloading ${name} -> ${target_dir}"
  curl_args=(-fL --retry 5 --retry-delay 3 -C - -o "${target_path}")
  if [[ -n "${HF_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi

  curl "${curl_args[@]}" "${url}"
done < "${model_list}"
