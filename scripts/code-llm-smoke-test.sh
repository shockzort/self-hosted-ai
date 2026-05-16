#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"

if [[ "${MODE:-gpu}" == "cpu" ]]; then
  compose_files=("${COMPOSE_CPU_FILES[@]}" -f compose.code-llm.yaml -f compose.code-llm.cpu.yaml)
else
  compose_files=("${COMPOSE_GPU_FILES[@]}" -f compose.code-llm.yaml -f compose.code-llm.gpu.yaml)
fi

compose=(docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}")
container_id="$("${compose[@]}" ps -q code-llm)"
if [[ -z "${container_id}" ]]; then
  echo "[fail] code-llm container is not running" >&2
  exit 1
fi
open_webui_id="$("${compose[@]}" ps -q open-webui || true)"

request_in_code_llm() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  if [[ -n "${payload}" ]]; then
    docker exec -i "${container_id}" sh -lc "curl -fsS --max-time 120 -X ${method} -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:8080${path}" <<<"${payload}"
  else
    docker exec "${container_id}" sh -lc "curl -fsS --max-time 30 -X ${method} http://127.0.0.1:8080${path}"
  fi
}

request_from_open_webui() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  [[ -n "${open_webui_id}" ]] || return 1
  if [[ -n "${payload}" ]]; then
    docker exec -i "${open_webui_id}" sh -lc "curl -fsS --max-time 120 -X ${method} -H 'Content-Type: application/json' --data-binary @- http://code-llm:8080${path}" <<<"${payload}"
  else
    docker exec "${open_webui_id}" sh -lc "curl -fsS --max-time 30 -X ${method} http://code-llm:8080${path}"
  fi
}

request_api() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  request_from_open_webui "${method}" "${path}" "${payload}" || request_in_code_llm "${method}" "${path}" "${payload}"
}

printf '[info] waiting for code-llm health endpoint\n'
for _ in $(seq 1 "${CODE_LLM_SMOKE_ATTEMPTS:-300}"); do
  if request_api GET /health >/tmp/self-hosted-ai-code-llm-health.json 2>/tmp/self-hosted-ai-code-llm-health.err; then
    printf '[ok] code-llm health endpoint is reachable\n'
    break
  fi
  sleep 2
done

if ! request_api GET /health >/tmp/self-hosted-ai-code-llm-health.json 2>/tmp/self-hosted-ai-code-llm-health.err; then
  printf '[fail] code-llm health endpoint did not become ready\n' >&2
  sed -n '1,80p' /tmp/self-hosted-ai-code-llm-health.err >&2 || true
  exit 1
fi

models_json="$(request_api GET /v1/models)"
MODELS_JSON="${models_json}" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["MODELS_JSON"])
ids = [item.get("id") for item in data.get("data", [])]
if not ids:
    raise SystemExit("[fail] /v1/models returned no model ids")
print("[ok] /v1/models:", ", ".join(ids))
PY

model="${CODE_LLM_ALIAS:-code/gemma4-fast}"
chat_max_tokens="${CODE_LLM_SMOKE_CHAT_MAX_TOKENS:-192}"
chat_payload="$(python3 - <<PY
import json
print(json.dumps({
    "model": "${model}",
    "messages": [
        {"role": "system", "content": "Reply with one short sentence."},
        {"role": "user", "content": "Say that the local code API is ready."},
    ],
    "max_tokens": int("${chat_max_tokens}"),
    "temperature": 0,
}))
PY
)"
chat_json="$(request_api POST /v1/chat/completions "${chat_payload}")"
CHAT_JSON="${chat_json}" STRICT_CHAT_SMOKE="${STRICT_CHAT_SMOKE:-0}" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["CHAT_JSON"])
choice = data["choices"][0]
message = choice["message"]
content = message.get("content") or ""
reasoning = message.get("reasoning_content") or ""
if not content.strip():
    if reasoning.strip() and os.environ.get("STRICT_CHAT_SMOKE") != "1":
        finish_reason = choice.get("finish_reason", "unknown")
        print(f"[warn] chat completion returned reasoning only (finish_reason={finish_reason}); API is responding")
        raise SystemExit(0)
    raise SystemExit("[fail] chat completion returned empty content")
print("[ok] chat completion:", content.strip()[:180])
PY

tool_max_tokens="${CODE_LLM_SMOKE_TOOL_MAX_TOKENS:-192}"
tool_payload="$(python3 - <<PY
import json
print(json.dumps({
    "model": "${model}",
    "messages": [
        {"role": "user", "content": "Call get_project_name now."},
    ],
    "tools": [{
        "type": "function",
        "function": {
            "name": "get_project_name",
            "description": "Return the current project name.",
            "parameters": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
    }],
    "tool_choice": {"type": "function", "function": {"name": "get_project_name"}},
    "max_tokens": int("${tool_max_tokens}"),
    "temperature": 0,
}))
PY
)"
tool_json="$(request_api POST /v1/chat/completions "${tool_payload}" || true)"
TOOL_JSON="${tool_json}" STRICT_TOOL_SMOKE="${STRICT_TOOL_SMOKE:-0}" python3 - <<'PY'
import json
import os
import sys

raw = os.environ["TOOL_JSON"]
try:
    data = json.loads(raw)
    message = data["choices"][0]["message"]
except Exception as exc:
    if os.environ.get("STRICT_TOOL_SMOKE") == "1":
        raise SystemExit(f"[fail] tool-call smoke returned invalid JSON: {exc}")
    print(f"[warn] tool-call smoke returned invalid JSON: {exc}")
    sys.exit(0)

tool_calls = message.get("tool_calls") or []
if tool_calls:
    names = [call.get("function", {}).get("name", "?") for call in tool_calls]
    print("[ok] tool-call response:", ", ".join(names))
elif os.environ.get("STRICT_TOOL_SMOKE") == "1":
    raise SystemExit("[fail] no tool_calls in forced tool-call response")
else:
    print("[warn] forced tool-call response had no tool_calls; basic API is up, but verify agent tool use with your target client")
PY

if [[ -n "${open_webui_id}" ]]; then
  docker exec "${open_webui_id}" sh -lc 'curl -fsS --max-time 30 http://code-llm:8080/v1/models >/dev/null'
  printf '[ok] Open WebUI container can reach code-llm at http://code-llm:8080/v1\n'
fi
