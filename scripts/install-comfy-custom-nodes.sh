#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

MANIFEST="${COMFY_CUSTOM_NODES_MANIFEST:-config/comfy-custom-nodes.tsv}"
CUSTOM_NODES_ROOT="${COMFY_CUSTOM_NODES_ROOT:-${SELF_HOSTED_AI_DATA_DIR}/comfyui/custom_nodes}"
TARGET="${1:-community}"

usage() {
  cat <<USAGE
Usage:
  $0 list
  $0 <bundle-or-slug>

Examples:
  $0 community
  $0 video-advanced
  $0 identity-consent

Custom nodes execute Python code inside ComfyUI. Review the repo before installing.
After installing nodes, restart ComfyUI. Set COMFYUI_INSTALL_EXTRA_REQUIREMENTS=1
in .env if you want the entrypoint to install requirements.txt files at startup.
USAGE
}

if [[ "${TARGET}" == "" || "${TARGET}" == "-h" || "${TARGET}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${TARGET}" == "list" ]]; then
  awk -F '\t' 'NF >= 5 && $1 !~ /^#/ { printf "%-20s %-28s %s\n", $2, $3, $5 }' "${MANIFEST}"
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to install custom nodes" >&2
  exit 1
fi

contains_bundle() {
  local bundles="$1"
  local needle="$2"
  [[ ",${bundles}," == *",${needle},"* ]]
}

matches=0
mkdir -p "${CUSTOM_NODES_ROOT}"

while IFS=$'\t' read -r bundles slug target_dir git_url notes; do
  [[ "${bundles}" =~ ^#.*$ || -z "${bundles}" ]] && continue
  if [[ "${slug}" != "${TARGET}" ]] && ! contains_bundle "${bundles}" "${TARGET}"; then
    continue
  fi

  matches=$((matches + 1))
  node_path="${CUSTOM_NODES_ROOT}/${target_dir}"
  echo "Installing custom node ${slug}: ${node_path}"
  [[ -n "${notes:-}" ]] && echo "  ${notes}"

  if [[ -d "${node_path}/.git" ]]; then
    git -C "${node_path}" pull --ff-only
  elif [[ -e "${node_path}" ]]; then
    echo "  Exists and is not a git checkout; skipping" >&2
  else
    git clone --depth 1 "${git_url}" "${node_path}"
  fi
done < "${MANIFEST}"

if [[ "${matches}" -eq 0 ]]; then
  echo "Unknown custom-node bundle or slug: ${TARGET}" >&2
  "$0" list >&2
  exit 1
fi

echo "Installed/updated ${matches} custom node repo(s). Restart ComfyUI to load them."
