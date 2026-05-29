#!/usr/bin/env bash

dcgm_exporter_ref() {
  printf '%s:%s\n' \
    "${DCGM_EXPORTER_IMAGE:-nvidia/dcgm-exporter}" \
    "${DCGM_EXPORTER_TAG:-4.5.2-4.8.1-distroless}"
}

dcgm_add_candidate() {
  local ref="$1"
  local existing

  [[ -n "${ref}" ]] || return 0

  for existing in "${dcgm_candidates[@]:-}"; do
    [[ "${existing}" == "${ref}" ]] && return 0
  done

  dcgm_candidates+=("${ref}")
}

dcgm_ref_to_env() {
  local ref="$1"
  local repo="${ref%:*}"
  local tag="${ref##*:}"

  if [[ "${repo}" == "${ref}" || "${tag}" == */* ]]; then
    printf '[fail] DCGM exporter image must include an explicit tag: %s\n' "${ref}" >&2
    return 1
  fi

  export DCGM_EXPORTER_IMAGE="${repo}"
  export DCGM_EXPORTER_TAG="${tag}"
}

resolve_dcgm_exporter_image() {
  local ref fallback
  dcgm_candidates=()

  if [[ "${DCGM_EXPORTER_AUTO_FALLBACK:-1}" != "1" ]]; then
    return 0
  fi

  if ! command -v docker >/dev/null 2>&1; then
    printf '[warn] docker is not available; skipping DCGM exporter image fallback check\n' >&2
    return 0
  fi

  dcgm_add_candidate "$(dcgm_exporter_ref)"
  for fallback in ${DCGM_EXPORTER_FALLBACK_IMAGES:-}; do
    dcgm_add_candidate "${fallback}"
  done

  for ref in "${dcgm_candidates[@]}"; do
    printf 'Checking DCGM exporter image %s\n' "${ref}"
    if docker image inspect "${ref}" >/dev/null 2>&1 || docker pull "${ref}"; then
      dcgm_ref_to_env "${ref}"
      printf '[ok] Using DCGM exporter image %s\n' "${ref}"
      return 0
    fi
    printf '[warn] Failed to pull DCGM exporter image %s\n' "${ref}" >&2
  done

  printf '[fail] No DCGM exporter image candidate could be pulled\n' >&2
  return 1
}
