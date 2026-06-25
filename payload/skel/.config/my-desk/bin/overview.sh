#!/usr/bin/env bash
# 壁纸概览脚本 — 将壁纸切换为模糊/暗化预览图
# ---------------------------------------------------------------------------
# 用法：overview.sh [壁纸路径]
#   如果提供壁纸路径，则使用它；否则从 awww 当前壁纸中获取。
# ---------------------------------------------------------------------------
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

# 获取壁纸路径
if [ -n "${1:-}" ]; then
  WALLPAPER="$1"
else
  sleep 0.5
  WALLPAPER=$(awww query | head -n1 | grep -oP 'image: \K.*')
fi

if [ -z "$WALLPAPER" ]; then
  echo "ERROR: No wallpaper path found!" >&2
  exit 1
fi

mkdir -p "${DESK_WALLPAPER_BLUR_CACHE}" "${DESK_WALLPAPER_OVERVIEW_CACHE}"
WALLPAPER="$(readlink -f "$WALLPAPER")"

FILENAME=$(basename "$WALLPAPER")
BLURRED_OVERVIEW="${DESK_WALLPAPER_OVERVIEW_CACHE}/overview_${FILENAME}"
BLURRED="${DESK_WALLPAPER_BLUR_CACHE}/blurred_${FILENAME}"

# 生成模糊缓存（如果没有）
if [ ! -f "$BLURRED" ] || [ ! -f "$BLURRED_OVERVIEW" ]; then
  magick "$WALLPAPER" -blur 0x15 -fill black -colorize 40% "$BLURRED_OVERVIEW"
  magick "$WALLPAPER" -blur 0x30 "$BLURRED"
fi

# 切换概览壁纸（淡入淡出效果）
awww img -n overview "$BLURRED_OVERVIEW" \
  --transition-type fade \
  --transition-duration 0.5

# 更新 rofi 壁纸缓存（软链接方式）
mkdir -p "${DESK_WALLPAPER_ROFI}" "${HOME}/.cache/wallpaper_rofi" "${DESK_STATE_DIR}/wallpaper"
rm -f "${DESK_WALLPAPER_ROFI}/current" "${DESK_WALLPAPER_ROFI}/blurred"
rm -f "${HOME}/.cache/wallpaper_rofi/current" "${HOME}/.cache/wallpaper_rofi/blurred"
printf '%s\n' "$WALLPAPER" > "${DESK_STATE_DIR}/wallpaper/current"
ln -sf "$WALLPAPER" "${DESK_WALLPAPER_ROFI}/current"
ln -sf "$BLURRED" "${DESK_WALLPAPER_ROFI}/blurred"
ln -sf "$WALLPAPER" "${HOME}/.cache/wallpaper_rofi/current"
ln -sf "$BLURRED" "${HOME}/.cache/wallpaper_rofi/blurred"
