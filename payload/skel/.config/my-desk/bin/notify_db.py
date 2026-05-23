#!/usr/bin/env python3
# 通知历史持久化 — 使用 my-desk 缓存目录
# ---------------------------------------------------------------------------
import sys
import os
import tempfile

CACHE_DIR = os.environ.get(
    "DESK_CACHE_DIR",
    os.path.expanduser("~/.cache/my-desk"),
)
CACHE_FILE = os.path.join(CACHE_DIR, "quickshell", "notification_history.json")


def load():
    """读取缓存"""
    if not os.path.exists(CACHE_FILE):
        print("[]")
        return
    try:
        with open(CACHE_FILE, "r") as f:
            data = f.read().strip()
            if not data:
                print("[]")
            else:
                print(data)
    except Exception as e:
        sys.stderr.write(f"Load error: {e}\n")
        print("[]")


def save(json_str):
    """写入缓存（原子写入）"""
    try:
        if not os.path.exists(CACHE_DIR):
            os.makedirs(CACHE_DIR)

        fd, temp_path = tempfile.mkstemp(dir=CACHE_DIR, prefix=".notif_tmp_")
        with os.fdopen(fd, 'w') as f:
            f.write(json_str)

        os.replace(temp_path, CACHE_FILE)

    except Exception as e:
        sys.stderr.write(f"Save error: {e}\n")
        if 'temp_path' in locals() and os.path.exists(temp_path):
            os.remove(temp_path)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "load":
        load()
    elif cmd == "save":
        if len(sys.argv) > 2:
            save(sys.argv[2])