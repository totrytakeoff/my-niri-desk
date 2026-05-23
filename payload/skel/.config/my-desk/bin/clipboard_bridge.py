#!/usr/bin/env python3

import base64
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from urllib.parse import unquote, urlparse


CACHE_DIR = Path.home() / ".cache" / "quickshell" / "clipboard"
IMAGE_CACHE_DIR = CACHE_DIR / "images"
IMAGE_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".bmp",
    ".tif",
    ".tiff",
    ".avif",
}
TEXT_PREVIEW_EXTENSIONS = {
    ".txt",
    ".md",
    ".log",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".ini",
    ".conf",
    ".sh",
    ".py",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".rs",
    ".go",
    ".java",
    ".kt",
    ".lua",
    ".qml",
    ".css",
    ".scss",
    ".html",
    ".xml",
}
IMAGE_PREVIEW_RE = re.compile(
    r"^\[\[\s*binary data\s+(?P<size>.+?)\s+(?P<fmt>[A-Za-z0-9+._-]+)\s+(?P<width>\d+)x(?P<height>\d+)\s*\]\]$",
    re.IGNORECASE,
)
TEXT_PREVIEW_BYTES = 12288


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def ensure_cache_dirs() -> None:
    IMAGE_CACHE_DIR.mkdir(parents=True, exist_ok=True)


def b64_json(data: dict) -> str:
    return base64.b64encode(json.dumps(data, ensure_ascii=False).encode("utf-8")).decode("ascii")


def decode_payload(payload_b64: str) -> dict:
    return json.loads(base64.b64decode(payload_b64.encode("ascii")).decode("utf-8"))


def decode_raw(raw_b64: str) -> str:
    return base64.b64decode(raw_b64.encode("ascii")).decode("utf-8")


def summarize(preview: str) -> str:
    text = preview.replace("\r", " ").replace("\n", " ").strip()
    while "  " in text:
        text = text.replace("  ", " ")
    return text[:240]


def parse_file_path(preview: str) -> Path | None:
    candidate = preview.strip()
    if candidate.startswith("file://"):
        parsed = urlparse(candidate)
        if parsed.scheme != "file":
            return None
        return Path(unquote(parsed.path))
    if candidate.startswith("/"):
        return Path(candidate)
    if candidate.startswith("~/"):
        return Path(candidate).expanduser()
    return None


def parse_file_entries(text: str) -> list[Path]:
    entries: list[Path] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        path = parse_file_path(line)
        if path is None:
            continue
        entries.append(path.expanduser())
    return entries


def decode_text_line(line: str) -> str:
    decoded = cliphist_decode_bytes(line)
    if not decoded:
        return ""
    return decoded.decode("utf-8", errors="replace").strip()


def mime_for_path(path: Path) -> str:
    mime, _ = mimetypes.guess_type(str(path))
    return mime or "application/octet-stream"


def format_bytes(size: int) -> str:
    units = ["B", "KiB", "MiB", "GiB"]
    value = float(size)
    for unit in units:
        if value < 1024.0 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024.0
    return f"{size} B"


def file_kind(path: Path) -> str:
    if path.is_dir():
        return "folder"
    if is_image_path(path):
        return "image"
    mime_type = mime_for_path(path)
    if mime_type.startswith("text/") or path.suffix.lower() in TEXT_PREVIEW_EXTENSIONS:
        return "text-file"
    if mime_type == "application/pdf":
        return "pdf"
    if mime_type.startswith("video/"):
        return "video"
    if mime_type.startswith("audio/"):
        return "audio"
    return "file"


def summarize_file_list(paths: list[Path]) -> tuple[str, str]:
    if not paths:
        return "(empty)", "File"
    first = paths[0]
    if len(paths) == 1:
        return first.name or str(first), str(first)
    return f"{first.name} +{len(paths) - 1}", f"{len(paths)} files"


def text_preview_for_path(path: Path) -> str:
    try:
        data = path.read_bytes()[:TEXT_PREVIEW_BYTES]
    except OSError:
        return ""
    text = data.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    if len(data) == TEXT_PREVIEW_BYTES:
        text += "\n..."
    return text.strip()


def folder_preview_for_path(path: Path, limit: int = 12) -> str:
    try:
        entries = sorted(path.iterdir(), key=lambda entry: (not entry.is_dir(), entry.name.lower()))
    except OSError:
        return ""

    lines: list[str] = []
    for entry in entries[:limit]:
        prefix = "[D]" if entry.is_dir() else "[F]"
        lines.append(f"{prefix} {entry.name}")
    if len(entries) > limit:
        lines.append(f"... +{len(entries) - limit} more")
    return "\n".join(lines)


def detail_meta_for_path(path: Path, kind: str) -> str:
    parts: list[str] = []
    try:
        stat = path.stat()
        if path.is_dir():
            try:
                count = sum(1 for _ in path.iterdir())
                parts.append(f"{count} items")
            except OSError:
                parts.append("Folder")
        else:
            parts.append(format_bytes(stat.st_size))
    except OSError:
        pass
    if kind != "folder":
        parts.append(mime_for_path(path))
    return " | ".join(part for part in parts if part)


def uri_list_bytes(paths: list[Path]) -> bytes:
    lines = [path.resolve().as_uri() for path in paths]
    return ("\r\n".join(lines) + "\r\n").encode("utf-8")


def plain_path_bytes(paths: list[Path]) -> bytes:
    return "\n".join(str(path) for path in paths).encode("utf-8")


def file_path_format(preview: str) -> str:
    return "uri" if preview.strip().startswith("file://") else "plain"


def transformed_file_mime(path_format: str) -> str:
    return "text/plain" if path_format == "uri" else "text/uri-list"


def transformed_file_bytes(paths: list[Path], path_format: str) -> bytes:
    if path_format == "uri":
        return plain_path_bytes(paths)
    return uri_list_bytes(paths)


def copy_path_payload(path: Path) -> str:
    return b64_json({"mode": "copy-path", "path": str(path)})


def build_file_item(
    item: dict,
    item_id: str,
    key: str,
    line: str,
    paths: list[Path],
) -> dict:
    first = paths[0]
    kind = file_kind(first)
    summary, subtitle = summarize_file_list(paths)
    path_format = file_path_format(line.split("\t", 1)[1] if "\t" in line else line)
    original_mime = "text/uri-list" if path_format == "uri" else "text/plain"

    item.update(
        {
            "type": "file",
            "summary": summary,
            "subtitle": subtitle,
            "sourcePath": str(first),
            "payload": b64_json({"mode": "cliphist", "line": line, "mime_type": original_mime}),
            "transformPayload": b64_json(
                {
                    "mode": "file-transform",
                    "paths": [str(path) for path in paths],
                    "from_format": path_format,
                    "raw": item["raw"],
                }
            ),
            "mimeType": original_mime,
            "fileKind": kind,
            "filePathFormat": path_format,
            "canTransform": True,
            "detailMeta": detail_meta_for_path(first, kind),
        }
    )

    if kind == "image" and len(paths) == 1:
        cached = cache_image_file(key, first)
        mime_type = mime_for_path(first)
        item.update(
            {
                "type": "image",
                "summary": first.name,
                "subtitle": f"Image file #{item_id}" if item_id else "Image file",
                "previewPath": cached.as_uri() if cached.exists() else first.as_uri(),
                "mimeType": mime_type,
                "detailMeta": detail_meta_for_path(first, kind),
                "filePathFormat": "",
                "canTransform": True,
                "transformPayload": copy_path_payload(first),
                "payload": b64_json(
                    {
                        "mode": "image-file",
                        "source_path": str(first),
                        "cache_path": str(cached),
                        "mime_type": mime_type,
                    }
                ),
                }
            )
    elif kind == "folder" and len(paths) == 1:
        item["previewText"] = folder_preview_for_path(first)
    elif kind == "text-file" and len(paths) == 1:
        item["previewText"] = text_preview_for_path(first)
    return item


def is_image_path(path: Path) -> bool:
    if path.suffix.lower() in IMAGE_EXTENSIONS:
        return True
    return mime_for_path(path).startswith("image/")


def parse_image_preview(preview: str) -> dict | None:
    match = IMAGE_PREVIEW_RE.match(preview.strip())
    if not match:
        return None
    fmt = match.group("fmt").lower()
    return {
        "format": fmt,
        "width": int(match.group("width")),
        "height": int(match.group("height")),
        "size": match.group("size"),
        "mime_type": mimetypes.types_map.get(f".{fmt}", f"image/{fmt}"),
    }


def cliphist_decode_bytes(line: str) -> bytes | None:
    decoded = subprocess.run(
        ["cliphist", "decode"],
        input=(line + "\n").encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if decoded.returncode != 0:
        return None
    return decoded.stdout


def cache_key(item_id: str, line: str) -> str:
    if item_id:
        return item_id
    return hashlib.sha256(line.encode("utf-8")).hexdigest()[:16]


def cache_image_bytes(key: str, extension: str, image_bytes: bytes) -> Path:
    ensure_cache_dirs()
    ext = extension if extension.startswith(".") else f".{extension}"
    path = IMAGE_CACHE_DIR / f"{key}{ext.lower()}"
    if not path.exists() or path.read_bytes() != image_bytes:
        path.write_bytes(image_bytes)
    return path


def cache_image_file(key: str, source_path: Path) -> Path:
    ensure_cache_dirs()
    ext = source_path.suffix.lower() or ".img"
    dest = IMAGE_CACHE_DIR / f"{key}{ext}"
    try:
        source_stat = source_path.stat()
    except OSError:
        return dest
    needs_copy = True
    if dest.exists():
        try:
            dest_stat = dest.stat()
            needs_copy = (
                dest_stat.st_size != source_stat.st_size
                or int(dest_stat.st_mtime) != int(source_stat.st_mtime)
            )
        except OSError:
            needs_copy = True
    if needs_copy:
        shutil.copy2(source_path, dest)
    return dest


def build_item(item_id: str, preview: str, line: str, index: int) -> dict:
    key = cache_key(item_id, line)
    file_path = parse_file_path(preview)
    image_meta = parse_image_preview(preview)
    decoded_text = ""

    item = {
        "index": index,
        "id": item_id,
        "type": "text",
        "summary": summarize(preview) or "(empty)",
        "subtitle": f"Text #{item_id}" if item_id else "Text",
        "previewPath": "",
        "sourcePath": "",
        "raw": base64.b64encode(line.encode("utf-8")).decode("ascii"),
        "payload": "",
        "mimeType": "text/plain",
        "fileKind": "",
        "filePathFormat": "",
        "canTransform": False,
        "transformPayload": "",
        "previewText": "",
        "detailMeta": "",
    }

    if image_meta:
        image_bytes = cliphist_decode_bytes(line)
        preview_path = ""
        cached_path = None
        if image_bytes:
            cached = cache_image_bytes(key, f".{image_meta['format']}", image_bytes)
            cached_path = cached
            preview_path = cached.as_uri()
        item.update(
            {
                "type": "image",
                "summary": f"{image_meta['width']} x {image_meta['height']}",
                "subtitle": f"{image_meta['format'].upper()} {image_meta['size']}" + (f" #{item_id}" if item_id else ""),
                "previewPath": preview_path,
                "sourcePath": str(cached_path) if cached_path else "",
                "mimeType": image_meta["mime_type"],
                "detailMeta": f"{image_meta['format'].upper()} | {image_meta['width']} x {image_meta['height']} | {image_meta['size']}",
                "canTransform": cached_path is not None,
                "transformPayload": copy_path_payload(cached_path) if cached_path else "",
                "payload": b64_json(
                    {
                        "mode": "cliphist",
                        "line": line,
                        "mime_type": image_meta["mime_type"],
                    }
                ),
            }
        )
        return item

    if file_path:
        file_path = file_path.expanduser()
        item["sourcePath"] = str(file_path)
        if file_path.exists():
            return build_file_item(item, item_id, key, line, [file_path])

    if preview.startswith(("file://", "/", "~/")):
        decoded_text = decode_text_line(line)
        decoded_paths = [path for path in parse_file_entries(decoded_text) if path.exists()]
        if decoded_paths:
            return build_file_item(item, item_id, key, line, decoded_paths)

        if file_path:
            item.update(
                {
                    "type": "file",
                    "summary": file_path.name or str(file_path),
                    "subtitle": str(file_path),
                    "payload": b64_json(
                        {
                            "mode": "cliphist",
                            "line": line,
                            "mime_type": "text/uri-list" if preview.startswith("file://") else "text/plain",
                        }
                    ),
                }
            )
            return item

    if preview.lower().startswith(("http://", "https://")):
        item.update(
            {
                "type": "link",
                "subtitle": f"Link #{item_id}" if item_id else "Link",
                "payload": b64_json({"mode": "cliphist", "line": line, "mime_type": "text/plain"}),
            }
        )
        return item

    item["payload"] = b64_json({"mode": "cliphist", "line": line, "mime_type": "text/plain"})
    return item


def _merge_pair(img: dict, src: dict) -> dict:
    if img["type"] != "image":
        img, src = src, img
    extra = {
        "type": src["type"],
        "summary": src.get("summary", ""),
        "subtitle": src.get("subtitle", ""),
        "sourcePath": src.get("sourcePath", ""),
        "mimeType": src.get("mimeType", ""),
        "fileKind": src.get("fileKind", ""),
        "detailMeta": src.get("detailMeta", ""),
        "previewText": src.get("previewText", ""),
    }
    merged = dict(img)
    merged["extraMime"] = extra
    merged["raw"] = b64_json([img.get("raw", ""), src.get("raw", "")])
    if not merged.get("sourcePath") and src.get("sourcePath"):
        merged["sourcePath"] = src["sourcePath"]
        
    # ✨ 【重构拓展】直接向 QML 根节点暴露的高价值拓展字段
    merged["hasExtraMime"] = True
    merged["extraMimeType"] = src.get("mimeType", "text/plain")
    merged["associatedPath"] = src.get("sourcePath", "") or src.get("summary", "")
    return merged


def list_items() -> int:
    if not command_exists("cliphist"):
        print(json.dumps({"ok": False, "error": "cliphist is not installed", "items": []}, ensure_ascii=False))
        return 0

    proc = subprocess.run(["cliphist", "list"], text=True, capture_output=True)
    if proc.returncode != 0:
        print(json.dumps({"ok": False, "error": proc.stderr.strip() or "cliphist list failed", "items": []}, ensure_ascii=False))
        return 0

    ensure_cache_dirs()
    items = []
    for idx, line in enumerate(proc.stdout.splitlines()):
        if not line:
            continue
        if "\t" in line:
            item_id, preview = line.split("\t", 1)
        else:
            item_id, preview = "", line
        items.append(build_item(item_id, preview, line, idx))

    # 🛠️ 【微信专项修复】非破坏性、时序无关的双向滑动窗口合并算法
    swallowed_indices = set()
    
    for i in range(len(items)):
        if items[i]["type"] == "image":
            img_id_str = items[i]["id"]
            if not img_id_str.isdigit():
                continue
            img_id = int(img_id_str)
            
            best_match_idx = None
            start_win = max(0, i - 3)
            end_win = min(len(items), i + 4)
            
            for j in range(start_win, end_win):
                if i == j or j in swallowed_indices:
                    continue
                candidate = items[j]
                
                # 判定当前项是否为合法的“伴生候选者”
                is_valid_candidate = False
                
                if candidate["type"] in ("text", "file", "link"):
                    is_valid_candidate = True
                elif candidate["type"] == "image":
                    # 🎯 核心修复点：如果候选条目也是 image，但它是从本地路径解析出来的（WeChat 缓存图）
                    # 且当前项是真正的剪切板二进制图，则必须要允许它们合并！
                    try:
                        current_mode = decode_payload(items[i]["payload"]).get("mode")
                        cand_mode = decode_payload(candidate["payload"]).get("mode")
                        if current_mode == "cliphist" and cand_mode == "image-file":
                            is_valid_candidate = True
                    except Exception:
                        pass
                
                if is_valid_candidate:
                    cand_id_str = candidate["id"]
                    if not cand_id_str.isdigit():
                        continue
                    cand_id = int(cand_id_str)
                    
                    # 临近条件：SQLite 内批处理生成的 ID 差绝对值不超过 2
                    if abs(img_id - cand_id) <= 2:
                        # 特征过滤：如果是转产的 image 默认放行，文本则继续严查路径/HTML特征
                        has_feature = (
                            candidate["type"] in ("file", "link", "image") or
                            candidate["summary"].startswith("/") or
                            candidate["summary"].startswith("~/") or
                            "file://" in candidate["summary"] or
                            "http" in candidate["summary"].lower() or
                            "<html" in candidate["summary"].lower()  # 顺便完美兼容 QQ 的 HTML 容器
                        )
                        if has_feature:
                            best_match_idx = j
                            break
            
            # 成功抓取到同源伴生数据，进行软合并
            if best_match_idx is not None:
                items[i] = _merge_pair(items[i], items[best_match_idx])
                swallowed_indices.add(best_match_idx)

    # 导出最终展现列表
    merged = []
    for idx, item in enumerate(items):
        if idx in swallowed_indices:
            continue
        merged.append(item)

    print(json.dumps({"ok": True, "error": "", "items": merged}, ensure_ascii=False))
    return 0


def copy_cliphist_item(line: str, mime_type: str | None = None) -> int:
    decoded = subprocess.run(
        ["cliphist", "decode"],
        input=(line + "\n").encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if decoded.returncode != 0:
        sys.stderr.buffer.write(decoded.stderr)
        return decoded.returncode
    return wl_copy_bytes(decoded.stdout, mime_type)


def wl_copy_bytes(data: bytes, mime_type: str | None = None) -> int:
    if not command_exists("wl-copy"):
        print("wl-copy is not installed", file=sys.stderr)
        return 1

    command = ["wl-copy"]
    if mime_type:
        command.extend(["--type", mime_type])
    copied = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    assert copied.stdin is not None
    copied.stdin.write(data)
    copied.stdin.close()
    time.sleep(0.05)
    if copied.poll() is not None and copied.returncode != 0:
        stderr = copied.stderr.read() if copied.stderr is not None else b""
        if stderr:
            sys.stderr.buffer.write(stderr)
        return copied.returncode
    return 0


def copy_item(payload_b64: str) -> int:
    payload = decode_payload(payload_b64)
    mode = payload.get("mode")

    if mode == "image-file":
        candidate_paths = [payload.get("source_path"), payload.get("cache_path")]
        for candidate in candidate_paths:
            if not candidate:
                continue
            path = Path(candidate)
            if path.exists():
                return wl_copy_bytes(path.read_bytes(), payload.get("mime_type") or mime_for_path(path))
        print("Image file is no longer available", file=sys.stderr)
        return 1

    if mode == "file-list":
        paths = [Path(path) for path in payload.get("paths", [])]
        existing = [path for path in paths if path.exists()]
        if not existing:
            print("File items are no longer available", file=sys.stderr)
            return 1
        return wl_copy_bytes(uri_list_bytes(existing), "text/uri-list")

    if mode == "cliphist":
        return copy_cliphist_item(payload["line"], payload.get("mime_type"))

    print("Unknown clipboard payload", file=sys.stderr)
    return 1


def transform_file_item(payload_b64: str) -> int:
    payload = decode_payload(payload_b64)
    if payload.get("mode") == "copy-path":
        path = Path(payload.get("path", ""))
        if not path.exists():
            print("Image path is no longer available", file=sys.stderr)
            return 1
        return wl_copy_bytes(str(path).encode("utf-8"), "text/plain")

    if payload.get("mode") != "file-transform":
        print("Unknown file transform payload", file=sys.stderr)
        return 1

    paths = [Path(path) for path in payload.get("paths", [])]
    existing = [path for path in paths if path.exists()]
    if not existing:
        print("File items are no longer available", file=sys.stderr)
        return 1

    from_format = payload.get("from_format", "plain")
    copied = wl_copy_bytes(transformed_file_bytes(existing, from_format), transformed_file_mime(from_format))
    if copied != 0:
        return copied

    # Give cliphist's wl-paste watcher a moment to store the transformed form
    # before removing the original raw entry from history.
    time.sleep(0.25)
    raw = payload.get("raw")
    if raw:
        return delete_item(raw)
    return 0


def paste_item(payload_b64: str) -> int:
    copied = copy_item(payload_b64)
    if copied != 0:
        return copied

    time.sleep(0.15)

    if command_exists("wtype"):
        pasted = subprocess.run(
            ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"],
            stderr=subprocess.PIPE,
        )
        if pasted.returncode != 0:
            sys.stderr.buffer.write(pasted.stderr)
        return pasted.returncode

    if command_exists("xdotool"):
        probe = subprocess.run(
            ["xdotool", "getactivewindow"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if probe.returncode == 0:
            pasted = subprocess.run(
                ["xdotool", "key", "--clearmodifiers", "ctrl+v"],
                stderr=subprocess.PIPE,
            )
            if pasted.returncode != 0:
                sys.stderr.buffer.write(pasted.stderr)
            return pasted.returncode

    if os.environ.get("XDG_SESSION_TYPE") == "wayland":
        print("Auto paste unavailable in Wayland without a stable focused target.", file=sys.stderr)
        return 1

    if command_exists("xdotool"):
        pasted = subprocess.run(
            ["xdotool", "key", "--clearmodifiers", "ctrl+v"],
            stderr=subprocess.PIPE,
        )
        if pasted.returncode != 0:
            sys.stderr.buffer.write(pasted.stderr)
        return pasted.returncode

    print("No paste injector found; clipboard updated only.", file=sys.stderr)
    return 0


def delete_item(raw_b64: str) -> int:
    if not command_exists("cliphist"):
        print("cliphist is not installed", file=sys.stderr)
        return 1

    raw_str = decode_raw(raw_b64)
    lines: list[str] = json.loads(raw_str) if raw_str.startswith("[") else [raw_str]
    for line in lines:
        # 🩹【自愈修复】合并卡片的 raw 列表提取出来是 base64，需要进行二次安全解码，防丢防漏
        actual_line = line
        if "\t" not in actual_line:
            try:
                actual_line = decode_raw(actual_line)
            except Exception:
                pass

        deleted = subprocess.run(
            ["cliphist", "delete"],
            input=actual_line + "\n",
            text=True,
            stderr=subprocess.PIPE,
        )
        if deleted.returncode != 0:
            sys.stderr.write(deleted.stderr)
    return 0


def wipe_items() -> int:
    if not command_exists("cliphist"):
        print("cliphist is not installed", file=sys.stderr)
        return 1

    wiped = subprocess.run(["cliphist", "wipe"], stderr=subprocess.PIPE)
    if wiped.returncode != 0:
        sys.stderr.buffer.write(wiped.stderr)
        return wiped.returncode

    if CACHE_DIR.exists():
        try:
            shutil.rmtree(CACHE_DIR)
        except OSError as exc:
            print(f"warning: failed to clear preview cache: {exc}", file=sys.stderr)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: clipboard_bridge.py [list|copy|paste|transform-file|delete|wipe]", file=sys.stderr)
        return 2

    command = sys.argv[1]
    if command == "list":
        return list_items()
    if command == "copy" and len(sys.argv) == 3:
        return copy_item(sys.argv[2])
    if command == "paste" and len(sys.argv) == 3:
        return paste_item(sys.argv[2])
    if command == "transform-file" and len(sys.argv) == 3:
        return transform_file_item(sys.argv[2])
    if command == "delete" and len(sys.argv) == 3:
        return delete_item(sys.argv[2])
    if command == "wipe":
        return wipe_items()

    print("invalid arguments", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
