#!/usr/bin/env python3

import argparse
import configparser
import hashlib
import json
import os
import re
import select
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import tomllib


CONFIG_PATH = Path.home() / ".config/niri/session-restore.toml"
DEFAULTS = {
    "enabled": True,
    "state_file": "~/.local/state/niri-session/last-session.json",
    "restore_delay_seconds": 6.0,
    "watch_startup_grace_seconds": 45.0,
    "watch_use_event_stream": True,
    "watch_poll_seconds": 30.0,
    "watch_debounce_seconds": 1.5,
    "watch_max_dirty_seconds": 10.0,
    "watch_periodic_save_seconds": 300.0,
    "watch_reconnect_seconds": 2.0,
    "launch_timeout_seconds": 25.0,
    "post_launch_settle_seconds": 1.0,
    "include_floating_windows": True,
    "launch_once_app_ids": ["code", "zen"],
    "exclude_app_ids": [],
}
FIELD_CODE_RE = re.compile(r"%[fFuUdDnNickvm]")


@dataclass
class DesktopEntry:
    path: Path
    name: str | None
    startup_wm_class: str | None
    command: list[str]


def load_config() -> dict:
    config = dict(DEFAULTS)
    if CONFIG_PATH.exists():
        with CONFIG_PATH.open("rb") as fh:
            data = tomllib.load(fh)
        config.update(data)

    config["state_file"] = str(Path(os.path.expanduser(config["state_file"])))
    config["launch_once_app_ids"] = set(config.get("launch_once_app_ids", []))
    config["exclude_app_ids"] = set(config.get("exclude_app_ids", []))
    return config


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_json_command(*args: str):
    proc = subprocess.run(
        ["niri", "msg", "--json", *args],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(proc.stdout)


def run_action(*args: str) -> None:
    subprocess.run(["niri", "msg", "action", *args], check=True)


def sanitize_exec(exec_line: str) -> list[str]:
    tokens = shlex.split(exec_line, posix=True)
    command = []
    for token in tokens:
        cleaned = FIELD_CODE_RE.sub("", token).strip()
        if cleaned:
            command.append(cleaned)
    return command


def desktop_entry_paths() -> list[Path]:
    local = sorted((Path.home() / ".local/share/applications").glob("*.desktop"))
    system = sorted(Path("/usr/share/applications").glob("*.desktop"))
    return local + system


def build_desktop_index() -> list[DesktopEntry]:
    entries = []
    for path in desktop_entry_paths():
        cp = configparser.ConfigParser(interpolation=None)
        try:
            cp.read(path, encoding="utf-8")
        except Exception:
            continue
        if "Desktop Entry" not in cp:
            continue
        sec = cp["Desktop Entry"]
        exec_line = sec.get("Exec")
        if not exec_line:
            continue
        command = sanitize_exec(exec_line)
        if not command:
            continue
        entries.append(
            DesktopEntry(
                path=path,
                name=sec.get("Name"),
                startup_wm_class=sec.get("StartupWMClass"),
                command=command,
            )
        )
    return entries


DESKTOP_INDEX = build_desktop_index()


def resolve_launch_info(app_id: str) -> dict | None:
    app_id_cf = app_id.casefold()
    app_leaf_cf = app_id.split(".")[-1].casefold()

    for entry in DESKTOP_INDEX:
        if entry.path.stem.casefold() == app_id_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        if entry.path.stem.casefold() == app_leaf_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        if entry.startup_wm_class and entry.startup_wm_class.casefold() == app_id_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        if entry.startup_wm_class and entry.startup_wm_class.casefold() == app_leaf_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        if entry.name and entry.name.casefold() == app_leaf_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        exe = Path(entry.command[-1 if entry.command[0] == "env" else 0]).name.casefold()
        if exe == app_id_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    for entry in DESKTOP_INDEX:
        exe = Path(entry.command[-1 if entry.command[0] == "env" else 0]).name.casefold()
        if exe == app_leaf_cf:
            return {"desktop_file": entry.path.name, "command": entry.command}

    fallback = shutil.which(app_id)
    if fallback:
        return {"desktop_file": None, "command": [fallback]}

    fallback_leaf = shutil.which(app_id.split(".")[-1])
    if fallback_leaf:
        return {"desktop_file": None, "command": [fallback_leaf]}

    return None


def output_order(outputs: dict) -> list[str]:
    ordered = sorted(
        outputs.values(),
        key=lambda item: (
            item["logical"]["x"],
            item["logical"]["y"],
            item["name"],
        ),
    )
    return [item["name"] for item in ordered]


def should_capture_window(window: dict, workspaces_by_id: dict, config: dict) -> bool:
    app_id = window.get("app_id") or ""
    if not app_id:
        return False
    if app_id in config["exclude_app_ids"]:
        return False
    if window["workspace_id"] not in workspaces_by_id:
        return False
    if window.get("is_floating") and not config["include_floating_windows"]:
        return False
    return True


def capture_session(config: dict) -> dict:
    windows = run_json_command("windows")
    workspaces = run_json_command("workspaces")
    outputs = run_json_command("outputs")
    ordered_outputs = output_order(outputs)
    output_rank = {name: idx for idx, name in enumerate(ordered_outputs)}
    workspaces_by_id = {workspace["id"]: workspace for workspace in workspaces}

    session_windows = []
    for window in windows:
        if not should_capture_window(window, workspaces_by_id, config):
            continue
        workspace = workspaces_by_id[window["workspace_id"]]
        layout = window.get("layout") or {}
        pos = layout.get("pos_in_scrolling_layout") or [1, 1]
        session_windows.append(
            {
                "app_id": window["app_id"],
                "title": window["title"],
                "workspace_id": workspace["id"],
                "workspace_idx": workspace["idx"],
                "workspace_name": workspace["name"],
                "output": workspace["output"],
                "column": pos[0] or 1,
                "tile": pos[1] or 1,
                "floating": window["is_floating"],
                "focused": window["is_focused"],
                "focus_timestamp": window.get("focus_timestamp"),
                "launch": resolve_launch_info(window["app_id"]),
            }
        )

    session_windows.sort(
        key=lambda item: (
            output_rank.get(item["output"], 999),
            item["workspace_idx"],
            item["column"],
            item["tile"],
            item["app_id"],
            item["title"],
        )
    )

    focused_workspace = next((ws for ws in workspaces if ws["is_focused"]), None)
    return {
        "saved_at": now_iso(),
        "outputs": ordered_outputs,
        "focused_output": focused_workspace["output"] if focused_workspace else None,
        "focused_workspace_idx": focused_workspace["idx"] if focused_workspace else None,
        "windows": session_windows,
    }


def state_path(config: dict) -> Path:
    return Path(config["state_file"])


def write_state(session: dict, config: dict) -> None:
    target = state_path(config)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".tmp")
    tmp.write_text(json.dumps(session, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(target)


def load_state(config: dict) -> dict | None:
    target = state_path(config)
    if not target.exists():
        return None
    return json.loads(target.read_text(encoding="utf-8"))


def session_digest(session: dict) -> str:
    stable = json.dumps(
        {
            "outputs": session.get("outputs", []),
            "windows": session.get("windows", []),
        },
        ensure_ascii=False,
        sort_keys=True,
    )
    return hashlib.sha256(stable.encode("utf-8")).hexdigest()


def state_digest(config: dict) -> str | None:
    session = load_state(config)
    if not session:
        return None
    return session_digest(session)


def save_if_changed(config: dict, last_hash: str | None) -> str | None:
    session = capture_session(config)
    current_hash = session_digest(session)
    if current_hash != last_hash:
        write_state(session, config)
    return current_hash


def save_command(config: dict) -> int:
    if not config["enabled"]:
        print("niri-session: disabled in config")
        return 0
    session = capture_session(config)
    write_state(session, config)
    print(
        f"Saved {len(session['windows'])} window(s) to {config['state_file']} at {session['saved_at']}"
    )
    return 0


def sleep_seconds(seconds: float) -> None:
    if seconds > 0:
        time.sleep(seconds)


def available_outputs() -> list[str]:
    return list(run_json_command("outputs").keys())


def choose_output(target_output: str | None, current_outputs: list[str]) -> str:
    if target_output and target_output in current_outputs:
        return target_output
    return current_outputs[0]


def current_windows() -> list[dict]:
    return run_json_command("windows")


def current_window_ids() -> set[int]:
    return {window["id"] for window in current_windows()}


def match_specs_to_candidates(specs: list[dict], candidates: list[dict]) -> list[tuple[dict, dict]]:
    remaining_specs = specs[:]
    remaining_candidates = candidates[:]
    matched = []

    # 先做标题精确匹配，最大程度利用应用自己的会话恢复。
    for spec in specs:
        title = (spec.get("title") or "").strip()
        if not title:
            continue
        for candidate in list(remaining_candidates):
            if (candidate.get("title") or "").strip() == title:
                matched.append((spec, candidate))
                remaining_candidates.remove(candidate)
                remaining_specs.remove(spec)
                break

    remaining_specs.sort(key=lambda item: (item["output"], item["workspace_idx"], item["column"], item["tile"]))
    remaining_candidates.sort(key=lambda item: item["id"])
    for spec, candidate in zip(remaining_specs, remaining_candidates):
        matched.append((spec, candidate))

    return matched


def wait_for_windows(
    app_id: str,
    minimum_count: int,
    baseline_ids: set[int],
    claimed_ids: set[int],
    timeout: float,
) -> list[dict]:
    deadline = time.time() + timeout
    latest = []
    while time.time() < deadline:
        windows = current_windows()
        latest = [
            window
            for window in windows
            if window["app_id"] == app_id and window["id"] not in baseline_ids and window["id"] not in claimed_ids
        ]
        if len(latest) >= minimum_count:
            break
        time.sleep(0.5)
    return latest


def launch_app(command: list[str]) -> None:
    subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def place_window(window_id: int, spec: dict, columns: dict[tuple[str, int, int], int], current_outputs: list[str]) -> None:
    output = choose_output(spec.get("output"), current_outputs)
    workspace_idx = spec["workspace_idx"]

    run_action("move-window-to-monitor", "--id", str(window_id), output)
    run_action(
        "move-window-to-workspace",
        "--window-id",
        str(window_id),
        "--focus",
        "false",
        str(workspace_idx),
    )

    if spec.get("floating"):
        run_action("move-window-to-floating", "--id", str(window_id))
        return

    run_action("move-window-to-tiling", "--id", str(window_id))

    column = spec["column"]
    column_key = (output, workspace_idx, column)
    representative_id = columns.get(column_key)

    if representative_id is None:
        run_action("focus-window", "--id", str(window_id))
        run_action("move-column-to-index", str(column))
        columns[column_key] = window_id
        return

    run_action("focus-window", "--id", str(window_id))
    run_action("move-column-to-index", str(column + 1))
    run_action("focus-window", "--id", str(representative_id))
    run_action("consume-window-into-column")


def restore_command(config: dict, dry_run: bool = False) -> int:
    if not config["enabled"]:
        print("niri-session: disabled in config")
        return 0

    session = load_state(config)
    if not session:
        print(f"niri-session: no saved state at {config['state_file']}")
        return 0

    current_outputs = available_outputs()
    if not current_outputs:
        print("niri-session: no outputs available, skipping restore", file=sys.stderr)
        return 1

    baseline_ids = current_window_ids()
    claimed_ids: set[int] = set()
    columns: dict[tuple[str, int, int], int] = {}
    focus_target_id: int | None = None

    windows = session.get("windows", [])
    windows_by_app: dict[str, list[dict]] = {}
    for spec in windows:
        windows_by_app.setdefault(spec["app_id"], []).append(spec)

    for app_id, specs in windows_by_app.items():
        launch_info = next((spec.get("launch") for spec in specs if spec.get("launch")), None)
        if not launch_info:
            launch_info = resolve_launch_info(app_id)
        if not launch_info:
            print(f"niri-session: skip {app_id}: no launch command")
            continue

        if dry_run:
            print(f"[dry-run] {app_id}: {len(specs)} window(s), command={' '.join(launch_info['command'])}")
            continue

        if app_id in config["launch_once_app_ids"]:
            launch_app(launch_info["command"])
            sleep_seconds(config["post_launch_settle_seconds"])
            candidates = wait_for_windows(
                app_id,
                minimum_count=len(specs),
                baseline_ids=baseline_ids,
                claimed_ids=claimed_ids,
                timeout=config["launch_timeout_seconds"],
            )
            pairs = match_specs_to_candidates(specs, candidates)
            if len(pairs) < len(specs):
                print(f"niri-session: {app_id}: expected {len(specs)} window(s), got {len(pairs)}")
            for spec, window in pairs:
                claimed_ids.add(window["id"])
                place_window(window["id"], spec, columns, current_outputs)
                if spec.get("focused"):
                    focus_target_id = window["id"]
            continue

        for spec in specs:
            launch_app(launch_info["command"])
            candidates = wait_for_windows(
                app_id,
                minimum_count=1,
                baseline_ids=baseline_ids,
                claimed_ids=claimed_ids,
                timeout=config["launch_timeout_seconds"],
            )
            if not candidates:
                print(f"niri-session: {app_id}: failed to get a new window for {spec['title']!r}")
                continue
            window = sorted(candidates, key=lambda item: item["id"])[0]
            claimed_ids.add(window["id"])
            place_window(window["id"], spec, columns, current_outputs)
            if spec.get("focused"):
                focus_target_id = window["id"]

    if not dry_run and focus_target_id is not None:
        run_action("focus-window", "--id", str(focus_target_id))

    return 0


def watch_command(config: dict) -> int:
    if not config["enabled"]:
        print("niri-session: disabled in config")
        return 0

    sleep_seconds(config["watch_startup_grace_seconds"])

    last_hash = state_digest(config)
    try:
        last_hash = save_if_changed(config, last_hash)
    except subprocess.CalledProcessError as exc:
        print(f"niri-session watch: initial capture failed: {exc}", file=sys.stderr)
    except Exception as exc:
        print(f"niri-session watch: initial capture failed: {exc}", file=sys.stderr)

    if config.get("watch_use_event_stream", True):
        return watch_command_event_stream(config, last_hash)
    return watch_command_poll(config, last_hash)


def watch_command_poll(config: dict, last_hash: str | None) -> int:
    while True:
        try:
            last_hash = save_if_changed(config, last_hash)
        except subprocess.CalledProcessError as exc:
            print(f"niri-session watch: niri IPC error: {exc}", file=sys.stderr)
        except Exception as exc:
            print(f"niri-session watch: {exc}", file=sys.stderr)
        time.sleep(config["watch_poll_seconds"])


def event_requires_save(event_name: str) -> bool:
    return any(token in event_name for token in ("Window", "Workspace", "Output"))


def next_event_line(stream, timeout: float | None) -> str | None:
    if timeout is None:
        line = stream.readline()
        if not line:
            raise EOFError("event stream closed")
        return line

    ready, _, _ = select.select([stream], [], [], max(timeout, 0.0))
    if not ready:
        return None

    line = stream.readline()
    if not line:
        raise EOFError("event stream closed")
    return line


def watch_command_event_stream(config: dict, last_hash: str | None) -> int:
    debounce_seconds = float(config["watch_debounce_seconds"])
    max_dirty_seconds = float(config["watch_max_dirty_seconds"])
    periodic_seconds = float(config["watch_periodic_save_seconds"])
    reconnect_seconds = float(config["watch_reconnect_seconds"])

    last_save_monotonic = time.monotonic()
    dirty_since: float | None = None
    last_trigger_monotonic: float | None = None

    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )
            if proc.stdout is None:
                raise RuntimeError("failed to open niri event stream")

            while True:
                now = time.monotonic()
                timeout_candidates = []
                if periodic_seconds > 0:
                    timeout_candidates.append(max(0.0, periodic_seconds - (now - last_save_monotonic)))
                if dirty_since is not None and last_trigger_monotonic is not None:
                    timeout_candidates.append(max(0.0, debounce_seconds - (now - last_trigger_monotonic)))
                    timeout_candidates.append(max(0.0, max_dirty_seconds - (now - dirty_since)))
                timeout = min(timeout_candidates) if timeout_candidates else None

                line = next_event_line(proc.stdout, timeout)
                now = time.monotonic()

                if line is None:
                    should_save = False
                    if dirty_since is not None and last_trigger_monotonic is not None:
                        quiet_long_enough = now - last_trigger_monotonic >= debounce_seconds
                        dirty_too_long = now - dirty_since >= max_dirty_seconds
                        should_save = quiet_long_enough or dirty_too_long
                    elif periodic_seconds > 0 and now - last_save_monotonic >= periodic_seconds:
                        should_save = True

                    if should_save:
                        last_hash = save_if_changed(config, last_hash)
                        last_save_monotonic = now
                        dirty_since = None
                        last_trigger_monotonic = None
                    continue

                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue

                event_name = next(iter(event), "")
                if not event_requires_save(event_name):
                    continue

                if dirty_since is None:
                    dirty_since = now
                last_trigger_monotonic = now

                if max_dirty_seconds > 0 and now - dirty_since >= max_dirty_seconds:
                    last_hash = save_if_changed(config, last_hash)
                    last_save_monotonic = now
                    dirty_since = None
                    last_trigger_monotonic = None
        except subprocess.CalledProcessError as exc:
            print(f"niri-session watch: niri IPC error: {exc}", file=sys.stderr)
        except EOFError:
            print("niri-session watch: event stream closed, reconnecting", file=sys.stderr)
        except Exception as exc:
            print(f"niri-session watch: {exc}", file=sys.stderr)
        finally:
            if proc is not None:
                proc.terminate()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=1)
        time.sleep(reconnect_seconds)


def status_command(config: dict) -> int:
    session = load_state(config)
    if not session:
        print(f"No saved state at {config['state_file']}")
        return 1
    print(f"State file: {config['state_file']}")
    print(f"Saved at:   {session.get('saved_at')}")
    print(f"Windows:    {len(session.get('windows', []))}")
    app_counts: dict[str, int] = {}
    for spec in session.get("windows", []):
        app_counts[spec["app_id"]] = app_counts.get(spec["app_id"], 0) + 1
    for app_id, count in sorted(app_counts.items()):
        print(f"  {app_id}: {count}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Save and restore niri window sessions")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("save", help="Save current niri session state")
    restore = sub.add_parser("restore", help="Restore saved niri session state")
    restore.add_argument("--dry-run", action="store_true", help="Print launch plan without restoring")
    sub.add_parser("watch", help="Periodically autosave session state")
    sub.add_parser("status", help="Show saved session summary")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config()

    if args.command == "save":
        return save_command(config)
    if args.command == "restore":
        return restore_command(config, dry_run=args.dry_run)
    if args.command == "watch":
        return watch_command(config)
    if args.command == "status":
        return status_command(config)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
