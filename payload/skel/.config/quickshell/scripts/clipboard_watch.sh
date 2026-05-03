#!/bin/sh
set -eu

lock_file="${XDG_RUNTIME_DIR:-/tmp}/clipboard-watch.lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

watch_loop() {
  mime_type="$1"
  while true; do
    wl-paste --type "$mime_type" --watch cliphist store
    sleep 1
  done
}

watch_loop text &
watch_loop image &

wait
