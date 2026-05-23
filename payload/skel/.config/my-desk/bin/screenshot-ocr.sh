#!/usr/bin/env bash
# 选区截图 + OCR 识别脚本
# ---------------------------------------------------------------------------
# 依赖：grim, slurp, tesseract (chi_sim+eng), wl-copy
# ---------------------------------------------------------------------------
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_TMP_DIR}"

tmp_img="$(mktemp -p "${DESK_TMP_DIR}" --suffix=.png)"
trap 'rm -f "$tmp_img"' EXIT

# 选区截图
region="$(slurp)"
[ -n "$region" ] || exit 1

grim -g "$region" "$tmp_img"

# OCR
ocr_text="$(tesseract "$tmp_img" stdout -l chi_sim+eng --oem 1 --psm 6)"

# 去掉纯空白结果
if [ -z "${ocr_text//[[:space:]]/}" ]; then
  echo "OCR returned empty text." >&2
  exit 1
fi

# 复制到剪贴板
printf '%s' "$ocr_text" | wl-copy

# 终端里也打印出来，方便确认
printf '%s\n' "$ocr_text"