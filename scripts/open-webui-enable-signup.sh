#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${MODE:-gpu}"

set_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" .env; then
    sed -i "s#^${key}=.*#${key}=${value}#" .env
  else
    printf '%s=%s\n' "${key}" "${value}" >> .env
  fi
}

"${SCRIPT_DIR}/init.sh" >/dev/null
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/env.sh"
set_env OPEN_WEBUI_ENABLE_SIGNUP true
set_env DEFAULT_USER_ROLE user

python3 - <<'PY'
import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["SELF_HOSTED_AI_DATA_DIR"]) / "open-webui" / "webui.db"
if not db.exists():
    raise SystemExit(0)

conn = sqlite3.connect(db)
cur = conn.cursor()
rows = cur.execute("select id, data from config").fetchall()
for row_id, raw in rows:
    try:
        data = json.loads(raw)
    except Exception:
        continue
    data["ENABLE_SIGNUP"] = True
    data["DEFAULT_USER_ROLE"] = "user"
    cur.execute("update config set data = ? where id = ?", (json.dumps(data, ensure_ascii=False), row_id))
conn.commit()
PY

if [[ "${MODE}" == "cpu" ]]; then
  compose_files=("${COMPOSE_CPU_FILES[@]}")
else
  compose_files=("${COMPOSE_GPU_FILES[@]}")
fi

docker compose "${COMPOSE_ENV_ARGS[@]}" "${compose_files[@]}" up -d open-webui

echo "Open WebUI signup is enabled. Register the first account; it will become admin if no users exist yet."
