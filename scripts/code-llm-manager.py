#!/usr/bin/env python3
"""Small local web UI for managing the dedicated code llama.cpp server."""

from __future__ import annotations

import argparse
import csv
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import threading
import time
import uuid
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
PROFILE_FILE = ROOT / "config" / "code-llm-models.tsv"
DOWNLOAD_FILE = ROOT / "config" / "code-llm-downloads.tsv"
ENV_FILE = ROOT / ".env"

PROFILE_COLUMNS = [
    "profile",
    "description",
    "hf_repo",
    "hf_file",
    "alias",
    "ctx_size",
    "n_gpu_layers",
    "n_cpu_moe",
    "batch_size",
    "ubatch_size",
    "parallel",
    "reasoning",
    "reasoning_budget",
    "temp",
    "top_p",
    "top_k",
    "min_p",
    "presence_penalty",
    "repeat_penalty",
    "no_mmap",
    "flash_attn",
    "cache_type_k",
    "cache_type_v",
    "extra_args",
]

DOWNLOAD_COLUMNS = [
    "profile",
    "description",
    "hf_repo",
    "include",
    "local_dir",
    "local_file",
    "min_disk_gib",
]

PROFILE_DEFAULTS = {
    "ctx_size": "32768",
    "n_gpu_layers": "999",
    "n_cpu_moe": "",
    "batch_size": "512",
    "ubatch_size": "512",
    "parallel": "1",
    "reasoning": "off",
    "reasoning_budget": "",
    "temp": "0.7",
    "top_p": "0.8",
    "top_k": "20",
    "min_p": "0.0",
    "presence_penalty": "0.0",
    "repeat_penalty": "1.0",
    "no_mmap": "1",
    "flash_attn": "1",
    "cache_type_k": "q8_0",
    "cache_type_v": "q8_0",
    "extra_args": "",
    "min_disk_gib": "30",
}


@dataclass
class Job:
    id: str
    label: str
    command: list[str]
    env: dict[str, str] = field(default_factory=dict)
    status: str = "queued"
    returncode: int | None = None
    started_at: float = field(default_factory=time.time)
    finished_at: float | None = None
    output: list[str] = field(default_factory=list)


jobs: dict[str, Job] = {}
jobs_lock = threading.Lock()


def run_command(args: list[str], extra_env: dict[str, str] | None = None, timeout: int | None = 30) -> dict[str, Any]:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    try:
        proc = subprocess.run(
            args,
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return {"ok": proc.returncode == 0, "returncode": proc.returncode, "output": proc.stdout}
    except FileNotFoundError as exc:
        return {"ok": False, "returncode": 127, "output": str(exc)}
    except subprocess.TimeoutExpired as exc:
        return {"ok": False, "returncode": None, "output": exc.stdout or "command timed out"}


def start_job(label: str, command: list[str], extra_env: dict[str, str] | None = None) -> Job:
    job = Job(id=uuid.uuid4().hex[:12], label=label, command=command, env=extra_env or {})
    with jobs_lock:
        jobs[job.id] = job
    thread = threading.Thread(target=_run_job, args=(job,), daemon=True)
    thread.start()
    return job


def _run_job(job: Job) -> None:
    env = os.environ.copy()
    env.update(job.env)
    with jobs_lock:
        job.status = "running"
        job.started_at = time.time()
    try:
        proc = subprocess.Popen(
            job.command,
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            bufsize=1,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            with jobs_lock:
                job.output.append(line.rstrip("\n"))
                if len(job.output) > 600:
                    job.output = job.output[-600:]
        rc = proc.wait()
        with jobs_lock:
            job.returncode = rc
            job.status = "succeeded" if rc == 0 else "failed"
            job.finished_at = time.time()
    except Exception as exc:  # noqa: BLE001 - must surface any failure to UI.
        with jobs_lock:
            job.returncode = 1
            job.status = "failed"
            job.output.append(str(exc))
            job.finished_at = time.time()


def job_to_dict(job: Job) -> dict[str, Any]:
    return {
        "id": job.id,
        "label": job.label,
        "command": " ".join(shlex.quote(part) for part in job.command),
        "status": job.status,
        "returncode": job.returncode,
        "started_at": job.started_at,
        "finished_at": job.finished_at,
        "output": job.output,
    }


def load_env_file() -> dict[str, str]:
    env: dict[str, str] = {}
    if not ENV_FILE.exists():
        return env
    for raw_line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        try:
            parsed = shlex.split(value, posix=True)
            env[key] = parsed[0] if parsed else ""
        except ValueError:
            env[key] = value.strip().strip('"').strip("'")
    return env


def profile_model_dir(profile_id: str) -> str:
    if profile_id.startswith("gemma4-"):
        return "gemma4"
    if profile_id.startswith("qwen36-"):
        return "qwen36"
    if profile_id.startswith("qwen3-coder-"):
        return "qwen3-coder"
    if profile_id.startswith("glm5-"):
        return "glm5"
    return profile_id


def load_tsv(path: Path, columns: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    if not path.exists():
        return rows
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.reader(handle, delimiter="\t"):
            if not row or row[0].startswith("#"):
                continue
            padded = row + [""] * (len(columns) - len(row))
            rows.append(dict(zip(columns, padded[: len(columns)])))
    return rows


def write_tsv(path: Path, columns: list[str], rows: list[dict[str, str]]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["# " + columns[0], *columns[1:]])
        for row in rows:
            writer.writerow([row.get(column, "") for column in columns])
    tmp.replace(path)


def data_dir(env: dict[str, str]) -> Path:
    raw = env.get("SELF_HOSTED_AI_DATA_DIR") or "./data"
    path = Path(raw)
    if not path.is_absolute():
        path = ROOT / raw.removeprefix("./")
    return path


def local_model_path(profile: dict[str, str], env: dict[str, str]) -> Path:
    return data_dir(env) / "code-llm" / "models" / profile_model_dir(profile["profile"]) / profile.get("hf_file", "")


def hf_cache_repo_dir(hf_repo: str, env: dict[str, str]) -> Path:
    repo = hf_repo.split(":", 1)[0]
    return data_dir(env) / "huggingface" / "hub" / ("models--" + repo.replace("/", "--"))


def cached_model_path(profile: dict[str, str], env: dict[str, str]) -> Path | None:
    hf_repo = profile.get("hf_repo", "")
    hf_file = profile.get("hf_file", "")
    if not hf_repo or not hf_file:
        return None
    snapshots = hf_cache_repo_dir(hf_repo, env) / "snapshots"
    if not snapshots.exists():
        return None
    for snapshot in snapshots.iterdir():
        candidate = snapshot / hf_file
        if candidate.exists():
            return candidate
    return None


def model_availability(profile: dict[str, str], env: dict[str, str]) -> dict[str, Any]:
    local_path = local_model_path(profile, env)
    if profile.get("hf_file") and local_path.exists():
        return {"available": True, "source": "local", "path": str(local_path)}
    cached_path = cached_model_path(profile, env)
    if cached_path is not None:
        return {"available": True, "source": "cache", "path": str(cached_path)}
    return {"available": False, "source": "missing", "path": str(local_path)}


def docker_container(name: str) -> dict[str, Any]:
    result = run_command(["docker", "inspect", name], timeout=10)
    if not result["ok"]:
        return {"exists": False, "name": name, "error": result["output"].strip()}
    try:
        raw = json.loads(result["output"])[0]
    except (KeyError, ValueError, IndexError) as exc:
        return {"exists": False, "name": name, "error": str(exc)}
    state = raw.get("State", {})
    return {
        "exists": True,
        "name": name,
        "image": raw.get("Config", {}).get("Image", ""),
        "status": state.get("Status", ""),
        "running": bool(state.get("Running")),
        "healthy": state.get("Health", {}).get("Status", ""),
        "started_at": state.get("StartedAt", ""),
    }


def ram_info() -> dict[str, int]:
    values: dict[str, int] = {}
    try:
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) >= 2:
                values[parts[0].rstrip(":")] = int(parts[1]) * 1024
    except OSError:
        return {}
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    return {
        "total": total,
        "available": available,
        "used": max(total - available, 0),
    }


def vram_info() -> list[dict[str, Any]]:
    result = run_command(
        [
            "nvidia-smi",
            "--query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
        ],
        timeout=10,
    )
    if not result["ok"]:
        return []
    gpus: list[dict[str, Any]] = []
    for line in result["output"].splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) < 7:
            continue
        try:
            gpus.append(
                {
                    "index": int(parts[0]),
                    "name": parts[1],
                    "total_mib": int(parts[2]),
                    "used_mib": int(parts[3]),
                    "free_mib": int(parts[4]),
                    "utilization": int(parts[5]),
                    "temperature": int(parts[6]),
                }
            )
        except ValueError:
            continue
    return gpus


def disk_info(env: dict[str, str]) -> dict[str, Any]:
    models = data_dir(env) / "code-llm" / "models"
    models.mkdir(parents=True, exist_ok=True)
    usage = shutil.disk_usage(models)
    return {
        "path": str(models),
        "total": usage.total,
        "used": usage.used,
        "free": usage.free,
    }


def status_payload() -> dict[str, Any]:
    env = load_env_file()
    profiles = load_tsv(PROFILE_FILE, PROFILE_COLUMNS)
    downloads = {row["profile"]: row for row in load_tsv(DOWNLOAD_FILE, DOWNLOAD_COLUMNS)}
    for profile in profiles:
        availability = model_availability(profile, env)
        profile["downloaded"] = availability["available"]
        profile["download_source"] = availability["source"]
        profile["local_path"] = availability["path"]
        profile["download"] = downloads.get(profile["profile"], {})
    active_profile = env.get("CODE_LLM_PROFILE", "gemma4-fast")
    return {
        "active_profile": active_profile,
        "active_alias": env.get("CODE_LLM_ALIAS", "code/gemma4-fast"),
        "env": {key: value for key, value in env.items() if key.startswith(("CODE_LLM", "OPEN_WEBUI", "SELF_HOSTED"))},
        "profiles": profiles,
        "downloads": list(downloads.values()),
        "containers": {
            "code_llm": docker_container(f"{env.get('COMPOSE_PROJECT_NAME', 'self-hosted-ai')}-code-llm-1"),
            "open_webui": docker_container(f"{env.get('COMPOSE_PROJECT_NAME', 'self-hosted-ai')}-open-webui-1"),
        },
        "ram": ram_info(),
        "vram": vram_info(),
        "disk": disk_info(env),
        "jobs": [job_to_dict(job) for job in list(jobs.values())[-20:]],
        "time": time.time(),
    }


def add_or_update_profile(payload: dict[str, Any]) -> dict[str, Any]:
    profile_id = str(payload.get("profile", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{1,63}", profile_id):
        raise ValueError("profile id must be 2-64 chars: letters, numbers, dot, underscore or dash")
    hf_repo = str(payload.get("hf_repo", "")).strip()
    hf_file = str(payload.get("hf_file", "")).strip()
    description = str(payload.get("description", "")).strip() or profile_id
    alias = str(payload.get("alias", "")).strip() or f"code/{profile_id}"

    profile_row = {column: "" for column in PROFILE_COLUMNS}
    profile_row.update(PROFILE_DEFAULTS)
    profile_row.update({key: str(payload.get(key, profile_row.get(key, ""))).strip() for key in PROFILE_COLUMNS})
    profile_row.update(
        {
            "profile": profile_id,
            "description": description,
            "hf_repo": hf_repo,
            "hf_file": hf_file,
            "alias": alias,
        }
    )

    profile_rows = load_tsv(PROFILE_FILE, PROFILE_COLUMNS)
    profile_rows = [row for row in profile_rows if row["profile"] != profile_id]
    profile_rows.append(profile_row)
    write_tsv(PROFILE_FILE, PROFILE_COLUMNS, profile_rows)

    download_row = {column: "" for column in DOWNLOAD_COLUMNS}
    local_dir = str(payload.get("local_dir", "")).strip() or profile_model_dir(profile_id)
    download_row.update(
        {
            "profile": profile_id,
            "description": description,
            "hf_repo": hf_repo,
            "include": str(payload.get("include", "")).strip() or hf_file,
            "local_dir": local_dir,
            "local_file": str(payload.get("local_file", "")).strip() or hf_file,
            "min_disk_gib": str(payload.get("min_disk_gib", PROFILE_DEFAULTS["min_disk_gib"])).strip(),
        }
    )
    download_rows = load_tsv(DOWNLOAD_FILE, DOWNLOAD_COLUMNS)
    download_rows = [row for row in download_rows if row["profile"] != profile_id]
    if hf_repo and hf_file:
        download_rows.append(download_row)
    write_tsv(DOWNLOAD_FILE, DOWNLOAD_COLUMNS, download_rows)
    return {"ok": True, "profile": profile_row, "download": download_row}


def latest_logs() -> str:
    env = load_env_file()
    name = f"{env.get('COMPOSE_PROJECT_NAME', 'self-hosted-ai')}-code-llm-1"
    return run_command(["docker", "logs", "--tail", "200", name], timeout=10)["output"]


HTML = r"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Code LLM Manager</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #0f1115;
      --panel: #171a21;
      --panel-2: #1d222c;
      --text: #e9edf3;
      --muted: #9aa5b1;
      --line: #2b3340;
      --accent: #4aa3ff;
      --good: #36c48a;
      --warn: #f5ad42;
      --bad: #ff6b6b;
      --button: #243142;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
      letter-spacing: 0;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 16px 22px;
      border-bottom: 1px solid var(--line);
      background: #11151b;
      position: sticky;
      top: 0;
      z-index: 5;
    }
    h1 { font-size: 20px; margin: 0; font-weight: 650; }
    main { padding: 18px 22px 28px; max-width: 1480px; margin: 0 auto; }
    .toolbar { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
    button, input, select, textarea {
      font: inherit;
      border-radius: 7px;
      border: 1px solid var(--line);
      background: var(--button);
      color: var(--text);
    }
    button {
      padding: 8px 11px;
      cursor: pointer;
      min-height: 36px;
    }
    button:hover { border-color: var(--accent); }
    button.primary { background: #174a7a; border-color: #2268a8; }
    button.danger { background: #4c2025; border-color: #7a3038; }
    button:disabled { opacity: .45; cursor: not-allowed; }
    input, select, textarea { padding: 8px 10px; width: 100%; background: #10141a; }
    textarea { min-height: 70px; resize: vertical; }
    .grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
    }
    .panel h2 { font-size: 15px; margin: 0 0 10px; }
    .metric { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; min-width: 0; }
    .metric > .muted { flex: 0 0 auto; }
    .metric strong { font-size: 21px; }
    .muted { color: var(--muted); overflow-wrap: anywhere; word-break: break-word; }
    .status { display: inline-flex; align-items: center; gap: 6px; min-width: 0; }
    .status.nowrap { white-space: nowrap; }
    .status.wrap { white-space: normal; overflow-wrap: anywhere; word-break: break-word; text-align: right; justify-content: flex-end; }
    .status.path { font-size: 11px; line-height: 1.25; max-width: 68%; align-items: flex-start; }
    .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--muted); display: inline-block; }
    .dot.good { background: var(--good); }
    .dot.warn { background: var(--warn); }
    .dot.bad { background: var(--bad); }
    .bar { height: 8px; border-radius: 999px; background: #0b0e13; overflow: hidden; margin-top: 10px; }
    .bar > span { display: block; height: 100%; background: var(--accent); width: 0%; }
    .section { margin-top: 18px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border-bottom: 1px solid var(--line); padding: 10px 8px; text-align: left; vertical-align: middle; }
    th { color: var(--muted); font-weight: 600; font-size: 12px; text-transform: uppercase; }
    td { font-size: 14px; }
    .actions { display: flex; gap: 7px; flex-wrap: wrap; }
    .tag { display: inline-flex; align-items: center; justify-content: center; text-align: center; padding: 3px 7px; border: 1px solid var(--line); border-radius: 999px; color: var(--muted); font-size: 12px; line-height: 1.25; }
    .tag.profile { min-width: 112px; max-width: 150px; white-space: normal; overflow-wrap: anywhere; }
    .tag.active { color: #c6f8df; border-color: #2e9b6b; background: #123d2a; }
    .tag.selected-unloaded { color: #ffe3bd; border-color: #b5762d; background: #3e2a14; }
    .tag.ok { color: #c6f8df; border-color: #277b55; background: #103824; }
    .tag.miss { color: #ffd2d2; border-color: #7d343b; background: #3a161a; }
    details summary { cursor: pointer; color: var(--text); font-weight: 650; }
    .form-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; margin-top: 12px; }
    .field label { display: block; color: var(--muted); font-size: 12px; margin-bottom: 5px; }
    .span-2 { grid-column: span 2; }
    .span-4 { grid-column: span 4; }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      background: #0b0e13;
      color: #dbe5ee;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 12px;
      max-height: 320px;
      overflow: auto;
      font-size: 12px;
    }
    .split { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    @media (max-width: 980px) {
      .grid, .split, .form-grid { grid-template-columns: 1fr; }
      .span-2, .span-4 { grid-column: span 1; }
      header { align-items: flex-start; flex-direction: column; }
      table, thead, tbody, tr, th, td { display: block; }
      thead { display: none; }
      tr { border-bottom: 1px solid var(--line); padding: 8px 0; }
      td { border-bottom: 0; padding: 6px 0; }
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>Code LLM Manager</h1>
      <div class="muted" id="subtitle">Загрузка состояния...</div>
    </div>
    <div class="toolbar">
      <button onclick="refresh()">Refresh</button>
      <button class="primary" onclick="action('start')">Start</button>
      <button class="danger" onclick="action('unload')">Unload</button>
      <button onclick="action('smoke')">Smoke</button>
      <button onclick="loadLogs()">Logs</button>
    </div>
  </header>
  <main>
    <section class="grid" id="metrics"></section>

    <section class="section panel">
      <h2>Profiles</h2>
      <div style="overflow-x:auto">
        <table>
          <thead>
            <tr>
              <th>Profile</th>
              <th>Model</th>
              <th>Ctx</th>
              <th>Local file</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody id="profiles"></tbody>
        </table>
      </div>
    </section>

    <section class="section split">
      <div class="panel">
        <details>
          <summary>Add or update model</summary>
          <form id="profileForm" class="form-grid">
            <div class="field"><label>Profile id</label><input name="profile" placeholder="my-coder-fast" required></div>
            <div class="field"><label>Alias</label><input name="alias" placeholder="code/my-coder-fast"></div>
            <div class="field span-2"><label>Description</label><input name="description" placeholder="Model description"></div>
            <div class="field span-2"><label>HF repo</label><input name="hf_repo" placeholder="org/model-GGUF"></div>
            <div class="field span-2"><label>HF file</label><input name="hf_file" placeholder="model-Q4_K_M.gguf"></div>
            <div class="field"><label>Context</label><input name="ctx_size" value="32768"></div>
            <div class="field"><label>GPU layers</label><input name="n_gpu_layers" value="999"></div>
            <div class="field"><label>CPU MoE layers</label><input name="n_cpu_moe"></div>
            <div class="field"><label>Reasoning</label><select name="reasoning"><option>off</option><option>on</option><option>auto</option></select></div>
            <div class="field"><label>Batch</label><input name="batch_size" value="512"></div>
            <div class="field"><label>uBatch</label><input name="ubatch_size" value="512"></div>
            <div class="field"><label>K cache</label><input name="cache_type_k" value="q8_0"></div>
            <div class="field"><label>V cache</label><input name="cache_type_v" value="q8_0"></div>
            <div class="field"><label>Local dir</label><input name="local_dir" placeholder="my-coder"></div>
            <div class="field"><label>Min disk GiB</label><input name="min_disk_gib" value="30"></div>
            <div class="field span-4"><label>Extra llama-server args</label><textarea name="extra_args" placeholder="--threads 16"></textarea></div>
            <div class="span-4 actions">
              <button type="submit" class="primary">Save profile</button>
              <button type="button" onclick="fillGlmHint()">GLM 5.1 template</button>
            </div>
          </form>
        </details>
      </div>
      <div class="panel">
        <h2>Jobs</h2>
        <div id="jobs" class="muted">No jobs yet</div>
      </div>
    </section>

    <section class="section panel">
      <h2>Output</h2>
      <pre id="output">No output yet</pre>
    </section>
  </main>

  <script>
    let state = null;
    let selectedJob = null;
    const fmtGiB = bytes => bytes ? (bytes / 1024 / 1024 / 1024).toFixed(1) + ' GiB' : 'n/a';
    const pct = (used, total) => total ? Math.min(100, Math.round(used * 100 / total)) : 0;
    const esc = value => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));

    async function api(path, options) {
      const res = await fetch(path, options);
      const text = await res.text();
      let data;
      try { data = JSON.parse(text); } catch { data = {ok: false, error: text}; }
      if (!res.ok) throw new Error(data.error || text || res.statusText);
      return data;
    }

    async function refresh() {
      state = await api('/api/status');
      render();
    }

    function render() {
      document.getElementById('subtitle').textContent = `Active: ${state.active_profile} / ${state.active_alias}`;
      renderMetrics();
      renderProfiles();
      renderJobs();
    }

    function renderMetrics() {
      const c = state.containers.code_llm;
      const ram = state.ram || {};
      const disk = state.disk || {};
      const gpu = (state.vram || [])[0] || {};
      const gpuUsedBytes = (gpu.used_mib || 0) * 1024 * 1024;
      const gpuTotalBytes = (gpu.total_mib || 0) * 1024 * 1024;
      const items = [
        ['Service', c.running ? 'running' : 'stopped', c.healthy || c.status || 'unknown', c.running ? 'good' : 'bad', null, false, true],
        ['RAM', fmtGiB(ram.available) + ' free', `${fmtGiB(ram.used)} / ${fmtGiB(ram.total)}`, 'good', pct(ram.used, ram.total), false, true],
        ['VRAM', gpu.free_mib != null ? `${gpu.free_mib} MiB free` : 'n/a', gpu.name ? `${gpu.used_mib} / ${gpu.total_mib} MiB` : 'nvidia-smi unavailable', 'good', pct(gpuUsedBytes, gpuTotalBytes), false, true],
        ['Model disk', fmtGiB(disk.free) + ' free', disk.path || '', 'good', pct(disk.used, disk.total), true, false],
      ];
      document.getElementById('metrics').innerHTML = items.map(item => `
        <div class="panel">
          <div class="metric"><span class="muted">${esc(item[0])}</span><span class="status ${item[5] ? 'wrap path' : 'nowrap'}">${item[6] ? `<span class="dot ${item[3]}"></span>` : ''}${esc(item[2])}</span></div>
          <strong>${esc(item[1])}</strong>
          ${item[4] != null ? `<div class="bar"><span style="width:${item[4]}%"></span></div>` : ''}
        </div>
      `).join('');
    }

    function renderProfiles() {
      const codeRunning = Boolean(state.containers?.code_llm?.running);
      document.getElementById('profiles').innerHTML = state.profiles.map(p => {
        const active = p.profile === state.active_profile;
        const profileStateClass = active ? (codeRunning ? 'active' : 'selected-unloaded') : '';
        const downloaded = p.downloaded;
        const source = p.download_source || (downloaded ? 'local' : 'missing');
        const isHuge = Number(p.download?.min_disk_gib || 0) >= 100;
        const sourceClass = downloaded ? 'ok' : 'miss';
        const sourceText = source === 'cache' ? 'cached' : (downloaded ? 'downloaded' : 'missing');
        return `<tr>
          <td><span class="tag profile ${profileStateClass}">${esc(p.profile)}</span></td>
          <td><div>${esc(p.alias)}</div><div class="muted">${esc(p.description)}</div><div class="muted">${esc(p.hf_repo)}</div></td>
          <td>${esc(p.ctx_size)}</td>
          <td><span class="tag ${sourceClass}">${esc(sourceText)}</span><div class="muted">${esc(p.hf_file || 'remote auto-download')}</div><div class="muted">${esc(p.local_path || '')}</div></td>
          <td><div class="actions">
            <button onclick="profileAction('select','${esc(p.profile)}')">Select</button>
            <button class="primary" onclick="profileAction('switch','${esc(p.profile)}')">${active ? 'Restart' : 'Switch'}</button>
            <button onclick="profileAction('download','${esc(p.profile)}', ${isHuge})">Download</button>
            <button onclick="profileAction('dry_download','${esc(p.profile)}', false)">Dry run</button>
          </div></td>
        </tr>`;
      }).join('');
    }

    function renderJobs() {
      const jobs = (state.jobs || []).slice().reverse();
      document.getElementById('jobs').innerHTML = jobs.length ? jobs.map(job => `
        <div style="margin-bottom:8px">
          <button onclick="showJob('${job.id}')">${esc(job.status)}</button>
          <strong>${esc(job.label)}</strong>
          <div class="muted">${esc(job.command)}</div>
        </div>
      `).join('') : '<span class="muted">No jobs yet</span>';
    }

    async function action(name) {
      const data = await api('/api/actions', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({action:name})});
      selectedJob = data.job.id;
      document.getElementById('output').textContent = `Started ${data.job.label}\n${data.job.command}`;
      pollJob();
    }

    async function profileAction(name, profile, confirmHuge) {
      if (confirmHuge && !confirm(`Download ${profile}? This may be very large.`)) return;
      const data = await api('/api/actions', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({action:name, profile})});
      selectedJob = data.job.id;
      document.getElementById('output').textContent = `Started ${data.job.label}\n${data.job.command}`;
      pollJob();
    }

    async function showJob(id) {
      selectedJob = id;
      pollJob();
    }

    async function pollJob() {
      if (!selectedJob) return;
      const data = await api('/api/jobs/' + selectedJob);
      document.getElementById('output').textContent = data.job.output.join('\n') || data.job.command;
      await refresh();
      if (data.job.status === 'running' || data.job.status === 'queued') setTimeout(pollJob, 1500);
    }

    async function loadLogs() {
      const data = await api('/api/logs');
      document.getElementById('output').textContent = data.logs || 'No logs';
    }

    document.getElementById('profileForm').addEventListener('submit', async (event) => {
      event.preventDefault();
      const payload = Object.fromEntries(new FormData(event.target).entries());
      const data = await api('/api/profiles', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload)});
      document.getElementById('output').textContent = `Saved profile ${data.profile.profile}`;
      await refresh();
    });

    function fillGlmHint() {
      const form = document.getElementById('profileForm');
      const values = {
        profile: 'glm5-custom',
        alias: 'code/glm5-custom',
        description: 'Custom GLM 5+ GGUF profile',
        ctx_size: '88064',
        batch_size: '2048',
        ubatch_size: '512',
        cache_type_k: 'q6_0',
        cache_type_v: '',
        local_dir: 'glm5',
        min_disk_gib: '180',
        extra_args: '-mla 1 -khad -mqkv -muge -wgt 1 -cuda graphs=1'
      };
      for (const [key, value] of Object.entries(values)) {
        if (form.elements[key]) form.elements[key].value = value;
      }
    }

    refresh().catch(err => {
      document.getElementById('output').textContent = err.stack || String(err);
    });
    setInterval(() => refresh().catch(() => {}), 7000);
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "CodeLLMManager/0.1"

    def log_message(self, fmt: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), fmt % args))

    def send_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        try:
            if path == "/":
                body = HTML.encode("utf-8")
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            elif path == "/api/status":
                self.send_json(status_payload())
            elif path == "/api/logs":
                self.send_json({"logs": latest_logs()})
            elif path.startswith("/api/jobs/"):
                job_id = path.rsplit("/", 1)[-1]
                with jobs_lock:
                    job = jobs.get(job_id)
                    if not job:
                        self.send_json({"error": "job not found"}, HTTPStatus.NOT_FOUND)
                        return
                    self.send_json({"job": job_to_dict(job)})
            else:
                self.send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)
        except Exception as exc:  # noqa: BLE001
            self.send_json({"error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        try:
            payload = self.read_json()
            if path == "/api/actions":
                self.handle_action(payload)
            elif path == "/api/profiles":
                self.send_json(add_or_update_profile(payload))
            else:
                self.send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)
        except ValueError as exc:
            self.send_json({"error": str(exc)}, HTTPStatus.BAD_REQUEST)
        except Exception as exc:  # noqa: BLE001
            self.send_json({"error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)

    def handle_action(self, payload: dict[str, Any]) -> None:
        action = str(payload.get("action", "")).strip()
        profile = str(payload.get("profile", "")).strip()
        script = str(ROOT / "scripts" / "code-llm.sh")
        commands = {
            "start": ([script, "start"], "Start current profile", {}),
            "unload": ([script, "unload"], "Unload model", {}),
            "stop": ([script, "unload"], "Unload model", {}),
            "smoke": ([script, "smoke"], "Smoke test", {}),
            "build_ik": ([script, "build-engine", "ik"], "Build ik_llama.cpp", {}),
        }
        if action in {"select", "switch", "download", "dry_download"}:
            if not profile:
                raise ValueError("profile is required")
            if action == "select":
                command, label, env = [script, "select", profile], f"Select {profile}", {}
            elif action == "switch":
                command, label, env = [script, "switch", profile], f"Switch to {profile}", {}
            elif action == "dry_download":
                command, label, env = [script, "download", profile], f"Dry-run download {profile}", {"DRY_RUN": "1"}
            else:
                command, label, env = [script, "download", profile], f"Download {profile}", {}
        elif action in commands:
            command, label, env = commands[action]
        else:
            raise ValueError(f"unknown action: {action}")
        job = start_job(label, command, env)
        self.send_json({"job": job_to_dict(job)})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.environ.get("CODE_LLM_MANAGER_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("CODE_LLM_MANAGER_PORT", "8091")))
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Code LLM Manager listening on http://{args.host}:{args.port}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
