#!/usr/bin/env bash
# 冻结画面后裁剪的区域截图脚本
# ---------------------------------------------------------------------------
# 流程：
# 1. 用 grim 立即截取当前聚焦的显示器，冻结当前画面；
# 2. 通过管道将未压缩图像直接交给 satty，默认进入裁剪工具；
# 3. 在冻结画面上选区并标注；
# 4. 保存到 $DESK_SCREENSHOT_DIR。
#
# 依赖：niri, jq, grim, satty, wl-copy
# ---------------------------------------------------------------------------

set -euo pipefail

# shellcheck source=../../my-desk/desk-env.sh
DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_SCREENSHOT_DIR}"

output="$(niri msg -j focused-output | jq -er '.name')"

grim -o "${output}" -t ppm - | satty \
  --filename - \
  --output-filename "${DESK_SCREENSHOT_DIR}/Screenshot-%Y-%m-%d-%H-%M-%S.png" \
  --fullscreen current-screen \
  --initial-tool crop \
  --copy-command wl-copy \
  --actions-on-right-click save-to-clipboard,exit \
  --disable-notifications
