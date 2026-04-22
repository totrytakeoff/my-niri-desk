#!/usr/bin/env python3
import json
import os
import re
import subprocess


def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def network_snapshot():
    wifi = {"state": "off", "name": "Not connected"}
    ethernet = {"device": "", "state": "unknown", "name": ""}

    lines = run(["bash", "-lc", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status"]).splitlines()
    for line in lines:
        parts = line.split(":")
        if len(parts) < 4:
            continue
        device, dev_type, state = parts[0], parts[1], parts[2]
        conn = ":".join(parts[3:])
        if dev_type == "wifi" and device.startswith("wl"):
            if state == "connected":
                wifi = {"state": "connected", "name": conn or "Wi-Fi"}
            elif wifi["state"] != "connected":
                wifi = {"state": state or "available", "name": conn or "Idle"}
        elif dev_type == "ethernet" and not device.startswith("veth"):
            ethernet = {"device": device, "state": state or "unknown", "name": conn}
            break
    return wifi, ethernet


def bluetooth_snapshot():
    powered = "yes" in run(["bash", "-lc", "bluetoothctl show | grep 'Powered:'"]).lower()
    connected = run(["bash", "-lc", "bluetoothctl devices Connected | wc -l"]).strip() or "0"
    return {"powered": powered, "connected_count": int(connected)}


def audio_snapshot():
    inspect = run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"])
    for line in inspect.splitlines():
        line = line.strip()
        if "node.description" in line or "device.description" in line or "node.nick" in line:
            if "=" in line:
                return line.split("=", 1)[1].strip().strip('"')
    return "Unknown output"


def power_profile():
    profile = run(["powerprofilesctl", "get"])
    return profile if profile else "unknown"


def battery_snapshot():
    battery = run(["bash", "-lc", "upower -e | grep BAT | head -1"])
    if not battery:
        return {"present": False, "percent": "", "state": ""}
    info = run(["upower", "-i", battery])
    percent = ""
    state = ""
    for line in info.splitlines():
        line = line.strip()
        if line.startswith("percentage:"):
            percent = line.split(":", 1)[1].strip()
        elif line.startswith("state:"):
            state = line.split(":", 1)[1].strip()
    return {"present": True, "percent": percent, "state": state}


if __name__ == "__main__":
    wifi, ethernet = network_snapshot()
    print(
        json.dumps(
            {
                "desktop": os.environ.get("XDG_SESSION_DESKTOP", "unknown"),
                "wifi": wifi,
                "ethernet": ethernet,
                "bluetooth": bluetooth_snapshot(),
                "audio_output": audio_snapshot(),
                "power_profile": power_profile(),
                "battery": battery_snapshot(),
            }
        )
    )
