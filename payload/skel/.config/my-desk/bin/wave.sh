#!/usr/bin/env bash
# cava 麦克风音频可视化 — 输出原始波形数据
# ---------------------------------------------------------------------------
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_TMP_DIR}"

# 动态获取系统当前的默认麦克风
MIC_SOURCE=$(pactl get-default-source)

config_file="${DESK_TMP_DIR}/cava_wave_config"
cat > "$config_file" <<CAVA_CFG
[general]
bars = 1
framerate = 30
autosens = 1

[input]
method = pulse
source = $MIC_SOURCE

[smoothing]
integral = 85
gravity = 50
noise_reduction = 0.8

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 60
channels = mono
CAVA_CFG

exec cava -p "$config_file"