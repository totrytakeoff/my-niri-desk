#!/usr/bin/env python3
import argparse
import json
import time

import psutil


def collect_processes(limit=28, sort_mode="cpu"):
    current_user = psutil.Process().username()
    vm = psutil.virtual_memory()
    total_mem = vm.total or 1
    cpu_usage = psutil.cpu_percent(interval=None)

    primed = []
    for proc in psutil.process_iter(["pid", "name", "username"]):
        try:
            if proc.info.get("username") != current_user:
                continue
            proc.cpu_percent(None)
            primed.append(proc)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    time.sleep(0.18)

    rows = []
    now = time.time()
    for proc in primed:
        try:
            with proc.oneshot():
                cpu = proc.cpu_percent(None)
                mem_bytes = proc.memory_info().rss
                mem_mb = mem_bytes / (1024 * 1024)
                mem_percent = (mem_bytes / total_mem) * 100
                status = proc.status()
                name = proc.info.get("name") or f"pid-{proc.pid}"
                cmdline = " ".join(proc.cmdline()[:5]).strip()
                age_sec = max(0, int(now - proc.create_time()))
                rows.append(
                    {
                        "pid": proc.pid,
                        "name": name,
                        "cpu": round(cpu, 1),
                        "mem_mb": round(mem_mb, 1),
                        "mem_percent": round(mem_percent, 1),
                        "status": status,
                        "cmdline": cmdline,
                        "age_sec": age_sec,
                    }
                )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    if sort_mode == "mem":
        rows.sort(key=lambda x: (x["mem_mb"], x["cpu"]), reverse=True)
    elif sort_mode == "name":
        rows.sort(key=lambda x: (x["name"].lower(), -x["cpu"], -x["mem_mb"]))
    else:
        rows.sort(key=lambda x: (x["cpu"], x["mem_mb"]), reverse=True)

    visible_rows = rows[:limit]
    total_cpu = round(sum(item["cpu"] for item in visible_rows), 1)
    total_mem_mb = round(sum(item["mem_mb"] for item in visible_rows), 1)
    total_mem_percent = round(sum(item["mem_percent"] for item in visible_rows), 1)

    return {
        "summary": {
            "count": len(visible_rows),
            "cpu_percent": round(cpu_usage, 1),
            "mem_percent": round(vm.percent, 1),
            "sample_cpu_total": total_cpu,
            "sample_mem_mb": total_mem_mb,
            "sample_mem_percent": total_mem_percent,
        },
        "rows": visible_rows,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=28)
    parser.add_argument("--sort", choices=["cpu", "mem", "name"], default="cpu")
    args = parser.parse_args()
    print(json.dumps(collect_processes(limit=args.limit, sort_mode=args.sort)))
