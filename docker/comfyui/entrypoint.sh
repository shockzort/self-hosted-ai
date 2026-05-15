#!/usr/bin/env bash
set -euo pipefail

cd /opt/ComfyUI

mkdir -p input output models custom_nodes user .cache/huggingface

if [[ "$(id -u)" == "0" ]]; then
  chown -R "${PUID:-1000}:${PGID:-1000}" input output models custom_nodes .cache
  find user -path user/default/workflows/local -prune -o -exec chown "${PUID:-1000}:${PGID:-1000}" {} +
  exec gosu "${PUID:-1000}:${PGID:-1000}" "$0" "$@"
fi

if [[ "${COMFYUI_INSTALL_EXTRA_REQUIREMENTS:-0}" == "1" ]]; then
  while IFS= read -r -d '' requirements_file; do
    python -m pip install -r "${requirements_file}"
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
      python -m pip install "${package_spec}"
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
