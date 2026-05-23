#!/usr/bin/env bash
# 区域截图脚本
# ---------------------------------------------------------------------------
# 流程：
# 1. 用 slurp 框选区域；
# 2. 用 grim 把区域截图保存到临时文件；
# 3. 用 satty 打开临时图，进入标注/编辑界面；
# 4. 保存到 $DESK_SCREENSHOT_DIR。
#
# 依赖：grim, slurp, satty, wl-copy
# ---------------------------------------------------------------------------

set -eu

# shellcheck source=../../my-desk/desk-env.sh
DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_SCREENSHOT_DIR}"

tmp="$(mktemp --suffix=.png)"
trap 'rm -f "${tmp}"' EXIT

grim -g "$(slurp)" "${tmp}"

satty \
  --filename "${tmp}" \
  --output-filename "${DESK_SCREENSHOT_DIR}/Screenshot-%Y-%m-%d-%H-%M-%S.png" \
  --floating-hack \
  --copy-command wl-copy \
  --actions-on-right-click save-to-clipboard,exit \
  --disable-notifications