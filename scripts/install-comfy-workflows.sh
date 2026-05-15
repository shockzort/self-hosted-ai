#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

MANIFEST="${COMFY_WORKFLOW_MANIFEST:-config/comfy-workflows.tsv}"
WORKFLOW_ROOT="${COMFY_WORKFLOW_ROOT:-workflows}"
TARGET="${1:-${COMFY_WORKFLOW_BUNDLE_ON_START:-starter}}"

usage() {
  cat <<USAGE
Usage:
  $0 list
  $0 <bundle-or-slug>

Bundles:
  starter  Small practical set: image, edit, video, audio.
  full     Heavier workflows, including 14B video and reference/style workflows.
  all      Every row in ${MANIFEST}.

Examples:
  $0 starter
  $0 full
  $0 flux-kontext
USAGE
}

if [[ "${TARGET}" == "" || "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${TARGET}" == "list" ]]; then
  awk -F '\t' 'NF >= 7 && $1 !~ /^#/ { printf "%-22s %-14s %s\n", $2, $3, $7 }' "${MANIFEST}"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to install and patch workflow JSON files" >&2
  exit 1
fi

matches=0
mkdir -p "${WORKFLOW_ROOT}"

contains_bundle() {
  local bundles="$1"
  local needle="$2"
  [[ ",${bundles}," == *",${needle},"* ]]
}

while IFS=$'\t' read -r bundles slug category filename url output_prefix notes; do
  [[ "${bundles}" =~ ^#.*$ || -z "${bundles}" ]] && continue

  if [[ "${TARGET}" != "all" && "${slug}" != "${TARGET}" ]] && ! contains_bundle "${bundles}" "${TARGET}"; then
    continue
  fi

  matches=$((matches + 1))
  target_dir="${WORKFLOW_ROOT}/${category}"
  target_path="${target_dir}/${filename}"
  tmp_path="$(mktemp)"
  mkdir -p "${target_dir}"

  echo "Installing workflow ${slug}: ${target_path}"
  [[ -n "${notes:-}" ]] && echo "  ${notes}"

  if [[ -f "${target_path}" && "${FORCE_WORKFLOWS:-${FORCE:-0}}" != "1" ]]; then
    echo "  Already exists; set FORCE_WORKFLOWS=1 to refresh"
    continue
  fi

  if [[ "${url}" == local:* ]]; then
    source_path="${url#local:}"
    if [[ ! -f "${source_path}" ]]; then
      echo "  Local workflow source is missing: ${source_path}" >&2
      rm -f "${tmp_path}"
      exit 1
    fi
    cp "${source_path}" "${tmp_path}"
  else
    curl -fsSL --retry 5 --retry-delay 3 -o "${tmp_path}" "${url}"
  fi

  jq --arg prefix "${output_prefix}" '
    if (.nodes | type) == "array" then
      .nodes |= map(
        if (.type | type) == "string"
           and (.type | test("^Save(Image|Video|Audio)$"))
           and (.widgets_values | type) == "array"
           and (.widgets_values | length) > 0
        then .widgets_values[0] = $prefix
        elif .type == "VHS_VideoCombine"
           and (.widgets_values | type) == "object"
           and (.widgets_values | has("filename_prefix"))
        then .widgets_values.filename_prefix = $prefix
        else .
        end
      )
    else .
    end
  ' "${tmp_path}" > "${target_path}"

  rm -f "${tmp_path}"
done < "${MANIFEST}"

if [[ "${matches}" -eq 0 ]]; then
  echo "Unknown workflow bundle or slug: ${TARGET}" >&2
  echo "Available workflows:" >&2
  "$0" list >&2
  exit 1
fi

echo "Installed ${matches} workflow(s) into ${WORKFLOW_ROOT}"
