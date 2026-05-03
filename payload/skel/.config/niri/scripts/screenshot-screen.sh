#!/bin/sh

# 全屏截图脚本 (兼容 Office Viewer/X11 插件版)
# ---------------------------------------------------------------------------

set -eu

out_dir="${HOME}/Pictures/Screenshots"
mkdir -p "${out_dir}"

file="${out_dir}/Screenshot-$(date +%Y-%m-%d-%H-%M-%S).png"

# 1. 截图并保存
grim "${file}"

# 2. 复制到 Wayland 剪贴板 (供原生 Wayland 应用使用)
wl-copy < "${file}"

# 3. 复制到 X11 剪贴板 (供 VS Code 插件等 XWayland 应用使用) ,目前直接依赖同步
# 注意：必须指定 -t image/png，否则插件可能识别不到格式 
# xclip -selection clipboard -t image/png < "${file}"