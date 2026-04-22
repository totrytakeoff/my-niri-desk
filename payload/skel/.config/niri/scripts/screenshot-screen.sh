#!/bin/sh

# 全屏截图脚本
# ---------------------------------------------------------------------------
# 流程：
# 1. grim 直接截整屏；
# 2. 保存到 ~/Pictures/Screenshots；
# 3. 自动复制到 Wayland 剪贴板。

set -eu

out_dir="${HOME}/Pictures/Screenshots"
mkdir -p "${out_dir}"

file="${out_dir}/Screenshot-$(date +%Y-%m-%d-%H-%M-%S).png"
grim "${file}"
wl-copy < "${file}"

# 常见扩展方向：
# grim -o HDMI-A-1 "${file}"
#   只截某一块屏幕。
#
# grim -g "$(slurp)" -
#   直接输出到 stdout，适合接别的处理链。
