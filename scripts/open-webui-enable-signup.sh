#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

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

./scripts/init.sh >/dev/null
set_env OPEN_WEBUI_ENABLE_SIGNUP true
set_env DEFAULT_USER_ROLE user

python3 - <<'PY'
import json
import sqlite3
from pathlib import Path

db = Path("data/open-webui/webui.db")
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

compose_files=(-f compose.yaml)
if [[ "${MODE}" == "cpu" ]]; then
  compose_files+=(-f compose.cpu.yaml)
else
  compose_files+=(-f compose.gpu.yaml)
fi

docker compose --env-file .env "${compose_files[@]}" up -d open-webui

echo "Open WebUI signup is enabled. Register the first account; it will become admin if no users exist yet."
