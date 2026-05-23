#!/bin/sh
set -eu

lock_file="${XDG_RUNTIME_DIR:-/tmp}/clipboard-watch.lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

watch_ttl="${CLIPBOARD_WATCH_TTL:-300}"

cleanup() {
  trap - INT TERM EXIT
  kill 0 >/dev/null 2>&1 || true
}

trap cleanup INT TERM EXIT

watch_loop() {
  mime_type="$1"
  stagger_delay="${2:-0}"

  if [ "$stagger_delay" -gt 0 ] 2>/dev/null; then
    sleep "$stagger_delay"
  fi

  while true; do
    rc=0
    timeout --foreground "${watch_ttl}" \
      wl-paste --type "$mime_type" --watch cliphist store || rc=$?
    case "$rc" in
      0|124|137|143) ;;
      *) sleep 1 ;;
    esac
    sleep 1
  done
}

watch_loop text 0 &
watch_loop image 15 &

wait
