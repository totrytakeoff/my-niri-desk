#!/bin/sh

# 区域截图脚本
# ---------------------------------------------------------------------------
# 流程：
# 1. 用 slurp 框选区域；
# 2. 用 grim 把区域截图保存到临时文件；
# 3. 用 satty 打开临时图，进入标注/编辑界面；
# 4. 保存到 ~/Pictures/Screenshots。
#
# 依赖：
# - grim
# - slurp
# - satty
# - wl-copy

set -eu

out_dir="${HOME}/Pictures/Screenshots"
mkdir -p "${out_dir}"

tmp="$(mktemp --suffix=.png)"
trap 'rm -f "${tmp}"' EXIT
# 无论脚本正常结束还是异常退出，都清理临时文件。

grim -g "$(slurp)" "${tmp}"

satty \
  --filename "${tmp}" \
  --output-filename "${out_dir}/Screenshot-%Y-%m-%d-%H-%M-%S.png" \
  --floating-hack \
  --copy-command wl-copy \
  --actions-on-right-click save-to-clipboard,exit \
  --disable-notifications
  # --default-hide-toolbars

# 说明：
# --default-hide-toolbars
#   工具栏默认隐藏，画面更干净；如果你想一打开就看到工具栏，可以删掉它。
#
# 常见可选项：
# --floating-hack
#   让 satty 主动请求以浮动窗口形式打开；对某些 Wayland 合成器更稳。
# --actions-on-right-click save-to-clipboard,exit
#   右键直接复制到剪贴板并关闭，最接近双击复制退出的快操作。
# --disable-notifications
#   关闭 satty 自己的通知，避免截图后打断继续输入/粘贴。
# --fullscreen current-screen
#   在当前屏幕全屏打开 satty。
# --early-exit
#   执行保存/复制后立即退出。
