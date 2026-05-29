#!/usr/bin/env bash
set -euo pipefail

cd /opt/ComfyUI

mkdir -p input output models custom_nodes user .cache/huggingface

if [[ "$(id -u)" == "0" ]]; then
  chown -R "${PUID:-1000}:${PGID:-1000}" input output models custom_nodes .cache
  find user -path user/default/workflows/local -prune -o -exec chown "${PUID:-1000}:${PGID:-1000}" {} +
  exec gosu "${PUID:-1000}:${PGID:-1000}" "$0" "$@"
fi

pip_install_args=()
if [[ -n "${COMFYUI_REQUIREMENTS_PIP_ARGS:-}" ]]; then
  read -r -a pip_install_args <<< "${COMFYUI_REQUIREMENTS_PIP_ARGS}"
fi

should_skip_requirements() {
  local requirements_file="$1"
  local pattern

  for pattern in ${COMFYUI_REQUIREMENTS_SKIP:-}; do
    if [[ "${requirements_file}" == ${pattern} ]]; then
      return 0
    fi
  done

  return 1
}

install_requirements() {
  local requirements_file="$1"
  local marker_dir="${COMFYUI_REQUIREMENTS_MARKER_DIR:-.cache/requirements}"
  local marker_file
  local requirements_hash
  local safe_name

  if should_skip_requirements "${requirements_file}"; then
    echo "[comfyui] Skipping custom node requirements: ${requirements_file}"
    return 0
  fi

  requirements_hash="$(sha256sum "${requirements_file}" | awk '{print $1}')"
  safe_name="$(printf '%s' "${requirements_file}" | sed 's#[^A-Za-z0-9_.-]#_#g')"
  marker_file="${marker_dir}/${safe_name}.sha256"

  if [[ "${COMFYUI_REQUIREMENTS_CACHE:-1}" == "1" && -f "${marker_file}" ]] \
    && [[ "$(cat "${marker_file}")" == "${requirements_hash}" ]]; then
    echo "[comfyui] Requirements unchanged, skipping: ${requirements_file}"
    return 0
  fi

  echo "[comfyui] Installing custom node requirements: ${requirements_file}"
  python -m pip install "${pip_install_args[@]}" -r "${requirements_file}"

  if [[ "${COMFYUI_REQUIREMENTS_CACHE:-1}" == "1" ]]; then
    mkdir -p "${marker_dir}"
    printf '%s\n' "${requirements_hash}" > "${marker_file}"
  fi
}

if [[ "${COMFYUI_INSTALL_EXTRA_REQUIREMENTS:-0}" == "1" ]]; then
  while IFS= read -r -d '' requirements_file; do
    install_requirements "${requirements_file}"
  done < <(find custom_nodes -maxdepth 2 -name requirements.txt -print0)
fi

if [[ -n "${COMFYUI_EXTRA_PIP_PACKAGES:-}" ]]; then
  for package_entry in ${COMFYUI_EXTRA_PIP_PACKAGES}; do
    import_name="${package_entry%%=*}"
    package_spec="${package_entry#*=}"
    if [[ "${package_entry}" != *"="* ]]; then
      package_spec="${package_entry}"
    fi

    if ! python -c "import ${import_name}" >/dev/null 2>&1; then
      echo "[comfyui] Installing extra Python package: ${package_spec}"
      python -m pip install "${pip_install_args[@]}" "${package_spec}"
    fi
  done
fi

if [[ "$#" -eq 0 ]]; then
  set -- python main.py --listen 0.0.0.0 --port 8188 --enable-manager
fi

if [[ -n "${COMFYUI_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2086
  exec "$@" ${COMFYUI_EXTRA_ARGS}
fi

exec "$@"
