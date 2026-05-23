#!/usr/bin/env bash
# desk-env.sh — my-desk 中心配置
# 所有工具脚本统一 source 此文件获取路径变量
# 修改此处即可全局重定向所有输出

# ============================================================
# 基础目录
# ============================================================
: "${DESK_CONFIG_DIR:="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"}"
: "${DESK_BIN_DIR:="${DESK_CONFIG_DIR}/bin"}"

# 添加到 PATH（如果尚未在 PATH 中）
case ":$PATH:" in
  *":$DESK_BIN_DIR:"*) ;;
  *) export PATH="$DESK_BIN_DIR:$PATH" ;;
esac

# ============================================================
# 输出目录（截图 / 录屏 / GIF / 录音）
# ============================================================
: "${DESK_OUTPUT_DIR:="$HOME/Downloads/Output"}"
: "${DESK_SCREENSHOT_DIR:="${DESK_OUTPUT_DIR}/Screenshots"}"
: "${DESK_VIDEO_DIR:="${DESK_OUTPUT_DIR}/videos"}"
: "${DESK_GIF_DIR:="${DESK_OUTPUT_DIR}/gif"}"
: "${DESK_AUDIO_SYS_DIR:="${DESK_OUTPUT_DIR}/audio_sys"}"
: "${DESK_AUDIO_MIC_DIR:="${DESK_OUTPUT_DIR}/audio_mic"}"

# ============================================================
# 临时文件目录
# ============================================================
: "${DESK_TMP_DIR:="${XDG_RUNTIME_DIR:-/tmp}/my-desk"}"
: "${DESK_TMP_LOG_DIR:="${DESK_TMP_DIR}/logs"}"

# ============================================================
# 缓存目录
# ============================================================
: "${DESK_CACHE_DIR:="$HOME/.cache/my-desk"}"
: "${DESK_WALLPAPER_BLUR_CACHE:="${DESK_CACHE_DIR}/wallpaper/blur"}"
: "${DESK_WALLPAPER_OVERVIEW_CACHE:="${DESK_CACHE_DIR}/wallpaper/overview"}"
: "${DESK_WALLPAPER_ROFI:="${DESK_CACHE_DIR}/wallpaper/rofi"}"

# ============================================================
# 状态文件
# ============================================================
: "${DESK_STATE_DIR:="$HOME/.local/state/my-desk"}"

# ============================================================
# 壁纸目录
# ============================================================
: "${DESK_WALLPAPER_DIR:="$HOME/.config/wallpaper"}"

# ============================================================
# 创建目录（延迟到首次使用，由各脚本按需创建）
# ============================================================
ensure_desk_dirs() {
  mkdir -p \
    "$DESK_SCREENSHOT_DIR" \
    "$DESK_VIDEO_DIR" \
    "$DESK_GIF_DIR" \
    "$DESK_AUDIO_SYS_DIR" \
    "$DESK_AUDIO_MIC_DIR" \
    "$DESK_TMP_DIR" \
    "$DESK_TMP_LOG_DIR" \
    "$DESK_CACHE_DIR" \
    "$DESK_WALLPAPER_BLUR_CACHE" \
    "$DESK_WALLPAPER_OVERVIEW_CACHE" \
    "$DESK_WALLPAPER_ROFI" \
    "$DESK_STATE_DIR"
}