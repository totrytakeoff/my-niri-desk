#!/usr/bin/env python3
"""Bridge Wayland clipboard → X11 :0 with loop protection.

Usage (via wl-paste --watch):
  wl-paste --type text     --watch clipboard_sync.py text/plain   :0
  wl-paste --type image    --watch clipboard_sync.py image/png    :0
"""
import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "quickshell" / "clipboard"
HASH_FILE = CACHE_DIR / "sync_hashes.json"
LOOP_WINDOW = 3.0


def main():
    # 规范化参数解析
    mime_type = sys.argv[1] if len(sys.argv) > 1 else "text/plain"
    display = sys.argv[2] if len(sys.argv) > 2 else ":0"

    data = sys.stdin.buffer.read()
    if not data:
        return

    current_hash = hashlib.sha256(data).hexdigest()
    # 跨进程持久化必须使用 epoch 绝对时间
    now = time.time()

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    stored: dict = {}
    if HASH_FILE.exists():
        try:
            stored = json.loads(HASH_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            stored = {}

    # 【核心修复】模糊匹配图片类型，防止 image 与 image/png 互不相认导致阻断失效
    is_image = "image" in mime_type
    lookup_key = "image_generic_lock" if is_image else mime_type

    entry = stored.get(lookup_key)
    if entry:
        last_hash = entry.get("hash")
        last_ts = entry.get("ts", 0.0)
        # Only suppress the same payload bouncing back through the bridge.
        # Different payloads copied quickly in succession should still sync.
        if last_hash == current_hash and (now - last_ts) < LOOP_WINDOW:
            return

    # 准备拉起 xclip
    xclip_args = ["xclip", "-selection", "clipboard", "-display", display]
    
    if is_image:
        # 如果是图片，强制指定为 image/png 灌入 X11，确保 xclip 能够正确识别
        xclip_args += ["-t", "image/png"]
    elif mime_type != "text/plain":
        xclip_args += ["-t", mime_type]

    # 执行写入，并静音标准输出避免管道阻塞
    subprocess.run(
        xclip_args, 
        input=data, 
        check=False, 
        stdout=subprocess.DEVNULL, 
        stderr=subprocess.DEVNULL
    )

    # 写入缓存，锁死回环
    stored[lookup_key] = {"hash": current_hash, "ts": now}
    try:
        HASH_FILE.write_text(json.dumps(stored))
    except OSError:
        pass


if __name__ == "__main__":
    main()
