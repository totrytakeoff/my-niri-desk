#!/usr/bin/env bash
# 录屏 / GIF / 录音 统一脚本
# ---------------------------------------------------------------------------
# 用法：
#   record start video         — 选区录视频
#   record start gif           — 选区录 GIF
#   record stop                — 停止录屏/GIF
#   record start audio_sys     — 录制系统音频
#   record start audio_mic     — 录制麦克风音频
#   record stop audio          — 停止录音
#
# 剪贴板行为：
#   - 视频/录音保存后 → 文件路径复制到剪贴板
#   - GIF 保存后       → 图像数据直接复制到剪贴板（可粘贴）
# ---------------------------------------------------------------------------
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_VIDEO_DIR}" "${DESK_GIF_DIR}" \
  "${DESK_AUDIO_SYS_DIR}" "${DESK_AUDIO_MIC_DIR}" \
  "${DESK_TMP_DIR}"

ACTION=$1
MODE=${2:-}

if [ "$ACTION" = "start" ]; then

  if [ "$MODE" = "audio_sys" ]; then
    FILE_PATH="${DESK_AUDIO_SYS_DIR}/SYS_$(date +%Y%m%d_%H%M%S).mp3"
    SINK_MONITOR=$(pactl get-default-sink).monitor
    ffmpeg -f pulse -i "$SINK_MONITOR" -y "$FILE_PATH" >"${DESK_TMP_DIR}/audio_ffmpeg.log" 2>&1 &
    echo $! >"${DESK_TMP_DIR}/audio_record.pid"
    echo "sys" >"${DESK_TMP_DIR}/audio_mode.txt"
    exit 0
  fi

  if [ "$MODE" = "audio_mic" ]; then
    FILE_PATH="${DESK_AUDIO_MIC_DIR}/MIC_$(date +%Y%m%d_%H%M%S).mp3"
    ffmpeg -f pulse -i default -y "$FILE_PATH" >"${DESK_TMP_DIR}/audio_ffmpeg.log" 2>&1 &
    echo $! >"${DESK_TMP_DIR}/audio_record.pid"
    echo "mic" >"${DESK_TMP_DIR}/audio_mode.txt"
    exit 0
  fi

  # 录屏 / GIF
  sleep 0.4
  COORDS=$(slurp)
  if [ -z "$COORDS" ]; then
    quickshell ipc call island cancelRecord
    exit 0
  fi

  if [ "$MODE" = "gif" ]; then
    # GIF：先录到临时 mp4，停止时再压制
    wf-recorder -g "$COORDS" -f "${DESK_TMP_DIR}/record.mp4" >"${DESK_TMP_DIR}/record.log" 2>&1 &
  else
    FILE_PATH="${DESK_VIDEO_DIR}/REC_$(date +%Y%m%d_%H%M%S).mp4"
    wf-recorder -g "$COORDS" -f "$FILE_PATH" >"${DESK_TMP_DIR}/record.log" 2>&1 &
  fi
  echo $! >"${DESK_TMP_DIR}/record.pid"

elif [ "$ACTION" = "stop" ]; then

  if [ "$MODE" = "audio" ]; then
    if [ -f "${DESK_TMP_DIR}/audio_record.pid" ]; then
      kill -INT "$(cat "${DESK_TMP_DIR}/audio_record.pid")"
      rm "${DESK_TMP_DIR}/audio_record.pid"

      LAST_MODE=$(cat "${DESK_TMP_DIR}/audio_mode.txt" 2>/dev/null)
      if [ "$LAST_MODE" = "sys" ]; then
        AUDIO_PATH="${DESK_AUDIO_SYS_DIR}/SYS_$(date +%Y%m%d_%H%M%S).mp3"
        notify-send "my-desk" "系统录音已保存"
      else
        AUDIO_PATH="${DESK_AUDIO_MIC_DIR}/MIC_$(date +%Y%m%d_%H%M%S).mp3"
        notify-send "my-desk" "麦克风录音已保存"
      fi
      # 复制文件路径到剪贴板（音频无法直接粘贴）
      printf '%s' "$AUDIO_PATH" | wl-copy
    fi
    exit 0
  fi

  # 停止录屏
  if [ -f "${DESK_TMP_DIR}/record.pid" ]; then
    kill -INT "$(cat "${DESK_TMP_DIR}/record.pid")"
    rm "${DESK_TMP_DIR}/record.pid"
    while pgrep -x wf-recorder >/dev/null; do sleep 0.1; done

    if [ "$MODE" = "gif" ]; then
      notify-send "my-desk" "正在压制 GIF..."
      GIF_PATH="${DESK_GIF_DIR}/GIF_$(date +%Y%m%d_%H%M%S).gif"
      ffmpeg -y -i "${DESK_TMP_DIR}/record.mp4" \
        -vf "fps=15,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        "$GIF_PATH" >"${DESK_TMP_DIR}/ffmpeg.log" 2>&1
      rm "${DESK_TMP_DIR}/record.mp4"
      # GIF 是图像，直接复制图像数据到剪贴板（可粘贴到聊天窗口等）
      wl-copy < "$GIF_PATH"
      notify-send "my-desk" "GIF 已保存并复制到剪贴板"
    else
      # 视频无法直接粘贴，复制文件路径到剪贴板
      printf '%s' "$FILE_PATH" | wl-copy
      notify-send "my-desk" "录屏已保存，文件路径已复制"
    fi
  fi
fi