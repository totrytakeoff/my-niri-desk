#!/usr/bin/env bash
# cava 音频可视化 — 输出 unicode 波形条
# ---------------------------------------------------------------------------
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
source "${DESK_CONFIG_DIR}/desk-env.sh"

mkdir -p "${DESK_TMP_DIR}"

bar="▁▂▃▄▅▆▇█"
dict="s/;//g;"

i=0
while [ $i -lt ${#bar} ]; do
  dict="${dict}s/$i/${bar:$i:1}/g;"
  i=$((i = i + 1))
done

config_file="${DESK_TMP_DIR}/cava_config"
cat > "$config_file" <<'CAVA_CFG'
[general]
bars = 18

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
CAVA_CFG

cava -p "$config_file" | while read -r line; do
  echo "$line" | sed "$dict"
done