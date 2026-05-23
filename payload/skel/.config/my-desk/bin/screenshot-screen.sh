#!/usr/bin/env bash
# 全屏截图脚本
# ---------------------------------------------------------------------------
set -eu

# shellcheck source=../../my-desk/desk-env.sh
DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_SCREENSHOT_DIR}"

file="${DESK_SCREENSHOT_DIR}/Screenshot-$(date +%Y-%m-%d-%H-%M-%S).png"

# 1. 截图并保存
grim "${file}"

# 2. 复制到 Wayland 剪贴板
wl-copy < "${file}"