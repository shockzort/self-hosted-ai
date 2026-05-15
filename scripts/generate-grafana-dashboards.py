#!/usr/bin/env python3
import json
from pathlib import Path


DASHBOARD_DIR = Path("monitoring/grafana/dashboards")
DS = {"type": "prometheus", "uid": "Prometheus"}
SERVICE_RE = "comfyui|ollama|open-webui|results|prometheus|grafana|cadvisor|node-exporter|dcgm-exporter"
SERVICE_LABEL = "container_label_com_docker_compose_service"
SERVICE_FILTER = f'{SERVICE_LABEL}=~"{SERVICE_RE}"'


def target(expr, legend="{{container_label_com_docker_compose_service}}", ref="A"):
    return {"expr": expr, "legendFormat": legend, "refId": ref}


def panel(pid, title, ptype, x, y, w, h, targets, unit="short", decimals=None):
    field_defaults = {"unit": unit}
    if decimals is not None:
        field_defaults["decimals"] = decimals

    base = {
        "id": pid,
        "title": title,
        "type": ptype,
        "datasource": DS,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": targets,
        "fieldConfig": {"defaults": field_defaults, "overrides": []},
    }

    if ptype == "timeseries":
        base["options"] = {
            "legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
            "tooltip": {"mode": "multi", "sort": "none"},
        }
    elif ptype == "stat":
        base["options"] = {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
        }
    elif ptype == "gauge":
        base["options"] = {
            "orientation": "auto",
            "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
            "showThresholdLabels": False,
            "showThresholdMarkers": True,
        }

    return base


def dashboard(title, uid, panels, tags):
    return {
        "annotations": {"list": []},
        "editable": True,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 1,
        "links": [],
        "liveNow": False,
        "panels": panels,
        "refresh": "10s",
        "schemaVersion": 39,
        "style": "dark",
        "tags": tags,
        "templating": {"list": []},
        "time": {"from": "now-1h", "to": "now"},
        "timezone": "browser",
        "title": title,
        "uid": uid,
        "version": 1,
        "weekStart": "",
    }


def write(name, data):
    path = DASHBOARD_DIR / name
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"Wrote {path}")


def main():
    DASHBOARD_DIR.mkdir(parents=True, exist_ok=True)

    service_cpu = f'sum by ({SERVICE_LABEL}) (rate(container_cpu_usage_seconds_total{{{SERVICE_FILTER}}}[5m]))'
    service_mem = f'container_memory_working_set_bytes{{{SERVICE_FILTER}}}'
    service_rx = f'sum by ({SERVICE_LABEL}) (rate(container_network_receive_bytes_total{{{SERVICE_FILTER}}}[5m]))'
    service_tx = f'sum by ({SERVICE_LABEL}) (rate(container_network_transmit_bytes_total{{{SERVICE_FILTER}}}[5m]))'
    service_reads = f'sum by ({SERVICE_LABEL}) (rate(container_fs_reads_bytes_total{{{SERVICE_FILTER}}}[5m]))'
    service_writes = f'sum by ({SERVICE_LABEL}) (rate(container_fs_writes_bytes_total{{{SERVICE_FILTER}}}[5m]))'

    overview = dashboard(
        "Inference Overview",
        "inference-overview",
        [
            panel(1, "GPU util now", "stat", 0, 0, 6, 4, [target("avg(DCGM_FI_DEV_GPU_UTIL)", "avg gpu")], "percent", 1),
            panel(2, "VRAM used now", "stat", 6, 0, 6, 4, [target("sum(DCGM_FI_DEV_FB_USED)", "used")], "mbytes", 0),
            panel(3, "Host RAM used", "stat", 12, 0, 6, 4, [target("100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)", "ram")], "percent", 1),
            panel(4, "Scrape targets up", "stat", 18, 0, 6, 4, [target('sum(up{job=~"cadvisor|dcgm-exporter|node-exporter|prometheus"})', "up")], "short", 0),
            panel(5, "GPU utilization", "timeseries", 0, 4, 12, 8, [target("DCGM_FI_DEV_GPU_UTIL", "gpu {{gpu}}")], "percent", 1),
            panel(6, "VRAM used/free", "timeseries", 12, 4, 12, 8, [target("DCGM_FI_DEV_FB_USED", "used gpu {{gpu}}"), target("DCGM_FI_DEV_FB_FREE", "free gpu {{gpu}}", "B")], "mbytes", 0),
            panel(7, "GPU temp and memory temp", "timeseries", 0, 12, 12, 8, [target("DCGM_FI_DEV_GPU_TEMP", "gpu temp {{gpu}}"), target("DCGM_FI_DEV_MEMORY_TEMP", "mem temp {{gpu}}", "B")], "celsius", 1),
            panel(8, "GPU power", "timeseries", 12, 12, 12, 8, [target("DCGM_FI_DEV_POWER_USAGE", "gpu {{gpu}}")], "watt", 1),
            panel(9, "Inference containers CPU", "timeseries", 0, 20, 12, 8, [target(service_cpu)], "short", 2),
            panel(10, "Inference containers memory", "timeseries", 12, 20, 12, 8, [target(service_mem)], "bytes", 0),
            panel(11, "Host CPU busy", "timeseries", 0, 28, 12, 8, [target('100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))', "{{instance}}")], "percent", 1),
            panel(12, "Host disk free", "timeseries", 12, 28, 12, 8, [target('node_filesystem_avail_bytes{mountpoint="/host",fstype!~"tmpfs|overlay|squashfs"}', "{{device}}")], "bytes", 0),
        ],
        ["inference", "overview"],
    )

    gpu = dashboard(
        "GPU / DCGM Deep Dive",
        "gpu-dcgm",
        [
            panel(1, "GPU utilization", "timeseries", 0, 0, 12, 8, [target("DCGM_FI_DEV_GPU_UTIL", "gpu {{gpu}}")], "percent", 1),
            panel(2, "Memory copy utilization", "timeseries", 12, 0, 12, 8, [target("DCGM_FI_DEV_MEM_COPY_UTIL", "gpu {{gpu}}")], "percent", 1),
            panel(3, "VRAM used/free/reserved", "timeseries", 0, 8, 12, 8, [target("DCGM_FI_DEV_FB_USED", "used {{gpu}}"), target("DCGM_FI_DEV_FB_FREE", "free {{gpu}}", "B"), target("DCGM_FI_DEV_FB_RESERVED", "reserved {{gpu}}", "C")], "mbytes", 0),
            panel(4, "GPU and memory temperature", "timeseries", 12, 8, 12, 8, [target("DCGM_FI_DEV_GPU_TEMP", "gpu {{gpu}}"), target("DCGM_FI_DEV_MEMORY_TEMP", "memory {{gpu}}", "B")], "celsius", 1),
            panel(5, "Power draw", "timeseries", 0, 16, 12, 8, [target("DCGM_FI_DEV_POWER_USAGE", "gpu {{gpu}}")], "watt", 1),
            panel(6, "SM and memory clocks", "timeseries", 12, 16, 12, 8, [target("DCGM_FI_DEV_SM_CLOCK", "sm {{gpu}}"), target("DCGM_FI_DEV_MEM_CLOCK", "mem {{gpu}}", "B")], "hertz", 0),
            panel(7, "Tensor / graphics / DRAM activity", "timeseries", 0, 24, 12, 8, [target("DCGM_FI_PROF_PIPE_TENSOR_ACTIVE * 100", "tensor {{gpu}}"), target("DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100", "graphics {{gpu}}", "B"), target("DCGM_FI_PROF_DRAM_ACTIVE * 100", "dram {{gpu}}", "C")], "percent", 1),
            panel(8, "PCIe traffic", "timeseries", 12, 24, 12, 8, [target("rate(DCGM_FI_PROF_PCIE_RX_BYTES[5m])", "rx {{gpu}}"), target("rate(DCGM_FI_PROF_PCIE_TX_BYTES[5m])", "tx {{gpu}}", "B")], "Bps", 1),
        ],
        ["inference", "gpu", "dcgm"],
    )

    host = dashboard(
        "Host & Containers",
        "host-containers",
        [
            panel(1, "Scrape target health", "timeseries", 0, 0, 12, 6, [target('up{job=~"cadvisor|dcgm-exporter|node-exporter|prometheus"}', "{{job}}")], "short", 0),
            panel(2, "Host load", "timeseries", 12, 0, 12, 6, [target("node_load1", "load1"), target("node_load5", "load5", "B"), target("node_load15", "load15", "C")], "short", 2),
            panel(3, "Container CPU cores", "timeseries", 0, 6, 12, 8, [target(service_cpu)], "short", 2),
            panel(4, "Container CPU throttling", "timeseries", 12, 6, 12, 8, [target(f'sum by ({SERVICE_LABEL}) (rate(container_cpu_cfs_throttled_periods_total{{{SERVICE_FILTER}}}[5m])) / sum by ({SERVICE_LABEL}) (rate(container_cpu_cfs_periods_total{{{SERVICE_FILTER}}}[5m]))')], "percentunit", 3),
            panel(5, "Container memory working set", "timeseries", 0, 14, 12, 8, [target(service_mem)], "bytes", 0),
            panel(6, "Container OOM events", "timeseries", 12, 14, 12, 8, [target(f'increase(container_oom_events_total{{{SERVICE_FILTER}}}[5m])')], "short", 0),
            panel(7, "Container network RX/TX", "timeseries", 0, 22, 12, 8, [target(service_rx, "rx {{container_label_com_docker_compose_service}}"), target(service_tx, "tx {{container_label_com_docker_compose_service}}", "B")], "Bps", 1),
            panel(8, "Container filesystem read/write", "timeseries", 12, 22, 12, 8, [target(service_reads, "read {{container_label_com_docker_compose_service}}"), target(service_writes, "write {{container_label_com_docker_compose_service}}", "B")], "Bps", 1),
            panel(9, "Host filesystem usage", "timeseries", 0, 30, 12, 8, [target('100 * (1 - node_filesystem_avail_bytes{mountpoint="/host",fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes{mountpoint="/host",fstype!~"tmpfs|overlay|squashfs"})', "{{device}}")], "percent", 1),
            panel(10, "Host disk IO", "timeseries", 12, 30, 12, 8, [target('rate(node_disk_read_bytes_total[5m])', "read {{device}}"), target('rate(node_disk_written_bytes_total[5m])', "write {{device}}", "B")], "Bps", 1),
        ],
        ["inference", "host", "containers"],
    )

    write("inference-overview.json", overview)
    write("gpu-dcgm.json", gpu)
    write("host-containers.json", host)


if __name__ == "__main__":
    main()
