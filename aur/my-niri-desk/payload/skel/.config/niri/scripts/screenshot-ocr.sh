#!/usr/bin/env bash
set -euo pipefail

tmp_img="$(mktemp --suffix=.png)"
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

# 复制到普通剪贴板
printf '%s' "$ocr_text" | wl-copy

# 终端里也打印出来，方便确认
printf '%s\n' "$ocr_text"