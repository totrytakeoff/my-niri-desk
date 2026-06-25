#!/usr/bin/env bash
set -euo pipefail

DESK_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-desk"
# shellcheck source=../desk-env.sh
source "${DESK_CONFIG_DIR}/desk-env.sh"

ensure_desk_dirs

state_file="${DESK_STATE_DIR}/wallpaper/current"
legacy_rofi_dir="${HOME}/.cache/wallpaper_rofi"
timer_unit="my-desk-wallpaper-random.timer"

first_existing_wallpaper() {
  local dir
  for dir in "${DESK_WALLPAPER_DIR}" "${HOME}/Pictures/wallpapers"; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      2>/dev/null | sort | head -n 1
  done | head -n 1
}

list_wallpapers() {
  local dir
  for dir in "${DESK_WALLPAPER_DIR}" "${HOME}/Pictures/wallpapers"; do
    [[ -d "${dir}" ]] || continue
    find "${dir}" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
      2>/dev/null
  done | sort -u
}

current_wallpaper() {
  local candidate

  if [[ -f "${state_file}" ]]; then
    candidate="$(head -n 1 "${state_file}")"
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  for candidate in "${DESK_WALLPAPER_ROFI}/current" "${legacy_rofi_dir}/current"; do
    if [[ -e "${candidate}" ]]; then
      candidate="$(readlink -f "${candidate}")"
      if [[ -n "${candidate}" && -f "${candidate}" ]]; then
        printf '%s\n' "${candidate}"
        return 0
      fi
    fi
  done

  first_existing_wallpaper
}

persist_wallpaper() {
  local wallpaper="$1"

  mkdir -p "$(dirname "${state_file}")" "${DESK_WALLPAPER_ROFI}" "${legacy_rofi_dir}"
  printf '%s\n' "${wallpaper}" > "${state_file}"

  rm -f "${DESK_WALLPAPER_ROFI}/current" "${legacy_rofi_dir}/current"
  ln -sf "${wallpaper}" "${DESK_WALLPAPER_ROFI}/current"
  ln -sf "${wallpaper}" "${legacy_rofi_dir}/current"
}

set_wallpaper() {
  local wallpaper="$1"
  local transition="${2:-any}"

  if [[ ! -f "${wallpaper}" ]]; then
    echo "wallpaper: not a file: ${wallpaper}" >&2
    exit 1
  fi

  wallpaper="$(readlink -f "${wallpaper}")"
  persist_wallpaper "${wallpaper}"

  if command -v awww >/dev/null 2>&1; then
    local attempt
    for attempt in 1 2 3 4 5; do
      if awww img "${wallpaper}" \
        --transition-type "${transition}" \
        --transition-duration 3 \
        --transition-fps 60 \
        --transition-bezier .43,1.19,1,.4; then
        break
      fi
      sleep 0.5
    done
  fi

  if command -v matugen >/dev/null 2>&1; then
    matugen image "${wallpaper}" --source-color-index 0 || true
  fi

  bash "${DESK_BIN_DIR}/overview.sh" "${wallpaper}" || true
}

random_wallpaper() {
  local current
  local selected

  current="$(current_wallpaper || true)"
  if [[ -n "${current}" ]]; then
    current="$(readlink -f "${current}")"
  fi

  selected="$(
    list_wallpapers | while IFS= read -r candidate; do
      candidate="$(readlink -f "${candidate}")"
      [[ "${candidate}" != "${current}" ]] && printf '%s\n' "${candidate}"
    done | shuf -n 1
  )"

  if [[ -z "${selected}" ]]; then
    selected="$(current_wallpaper || true)"
  fi

  [[ -n "${selected}" ]] || exit 0
  set_wallpaper "${selected}" "any"
}

timer_action() {
  local action="${1:-}"
  case "${action}" in
    on|enable|start)
      systemctl --user enable --now "${timer_unit}"
      ;;
    off|disable|stop)
      systemctl --user disable --now "${timer_unit}"
      ;;
    status)
      systemctl --user status "${timer_unit}" --no-pager
      ;;
    *)
      echo "Usage: wallpaper.sh timer {on|off|status}" >&2
      exit 1
      ;;
  esac
}

cmd="${1:-}"
case "${cmd}" in
  apply)
    shift
    [[ $# -ge 1 ]] || { echo "Usage: wallpaper.sh apply <path>" >&2; exit 1; }
    set_wallpaper "$1" "any"
    ;;
  restore)
    wallpaper="$(current_wallpaper)"
    [[ -n "${wallpaper}" ]] || exit 0
    set_wallpaper "${wallpaper}" "none"
    ;;
  current)
    current_wallpaper
    ;;
  random)
    random_wallpaper
    ;;
  timer)
    shift
    timer_action "${1:-}"
    ;;
  *)
    echo "Usage: wallpaper.sh {apply <path>|restore|current|random|timer {on|off|status}}" >&2
    exit 1
    ;;
esac
