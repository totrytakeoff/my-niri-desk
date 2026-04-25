#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
payload_root="${repo_root}/payload/skel"
temp_root="$(mktemp -d)"

mode="status"
dry_run=0
include_wallpaper=0

managed_paths=(
  ".config/niri"
  ".config/quickshell"
  ".config/fcitx5"
  ".config/hypr"
  ".config/fuzzel"
  ".config/mako"
  ".local/share/fcitx5/themes/NiriGlass"
)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sync-local-config.sh [status|pull|push] [--dry-run] [--include-wallpaper]

Modes:
  status    Compare local config against payload/skel and print drift. Default.
  pull      Sync payload/skel -> $HOME for managed paths. Deletes extra local files.
  push      Sync $HOME -> payload/skel for managed paths. Deletes extra repo files.

Options:
  --dry-run            Show what would change without writing.
  --include-wallpaper  Include .config/wallpaper in compare/sync operations.
  -h, --help           Show this help.

Notes:
  - This is a maintainer helper, not an end-user setup script.
  - pull/push use rsync --delete on managed paths.
  - Wallpaper is excluded by default because it often contains personal files.
EOF
}

cleanup() {
  rm -rf "${temp_root}"
}

trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

path_excludes() {
  local rel="$1"

  case "${rel}" in
    ".config/fcitx5")
      printf '%s\n' "cached_layouts" "notifications.conf_*"
      ;;
  esac
}

prepare_path() {
  local source_root="$1"
  local rel="$2"
  local direction="$3"
  local src="${source_root}/${rel}"
  local prepared="${temp_root}/${direction}/$(printf '%s' "${rel}" | tr '/' '_')"
  local escaped_home

  rm -rf "${prepared}"
  mkdir -p "$(dirname "${prepared}")"
  cp -a "${src}" "${prepared}"

  if [[ "${rel}" == ".config/hypr" && -f "${prepared}/hyprlock.conf" ]]; then
    case "${direction}" in
      repo_to_local)
        sed -i "s|@HOME@|${HOME}|g" "${prepared}/hyprlock.conf"
        ;;
      local_to_repo)
        escaped_home="$(printf '%s\n' "${HOME}" | sed 's/[.[\*^$+?(){|]/\\&/g')"
        sed -i "s|${escaped_home}|@HOME@|g" "${prepared}/hyprlock.conf"
        ;;
    esac
  fi

  printf '%s\n' "${prepared}"
}

compare_path() {
  local rel="$1"
  local local_path="${HOME}/${rel}"
  local repo_path="${payload_root}/${rel}"
  local prepared_repo_path
  local -a diff_args=( -rq )
  local -a excludes=()

  if [[ ! -e "${local_path}" && ! -e "${repo_path}" ]]; then
    return 0
  fi

  if [[ ! -e "${repo_path}" ]]; then
    echo "[repo-missing] ${rel}"
    return 1
  fi

  if [[ ! -e "${local_path}" ]]; then
    echo "[local-missing] ${rel}"
    return 1
  fi

  prepared_repo_path="$(prepare_path "${payload_root}" "${rel}" repo_to_local)"
  mapfile -t excludes < <(path_excludes "${rel}")
  for pattern in "${excludes[@]}"; do
    diff_args+=( "--exclude=${pattern}" )
  done

  if diff "${diff_args[@]}" "${local_path}" "${prepared_repo_path}" >/dev/null 2>&1; then
    echo "[ok] ${rel}"
    return 0
  fi

  echo "[drift] ${rel}"
  diff "${diff_args[@]}" "${local_path}" "${prepared_repo_path}" || true
  return 1
}

sync_path() {
  local source_root="$1"
  local target_root="$2"
  local rel="$3"
  local direction="$4"
  local src
  local dst="${target_root}/${rel}"
  local -a rsync_args=( -a --delete --itemize-changes )
  local -a excludes=()

  if (( dry_run )); then
    rsync_args+=( --dry-run )
  fi

  mapfile -t excludes < <(path_excludes "${rel}")
  for pattern in "${excludes[@]}"; do
    rsync_args+=( "--exclude=${pattern}" )
  done

  src="$(prepare_path "${source_root}" "${rel}" "${direction}")"

  if [[ ! -e "${src}" ]]; then
    echo "Source path missing, skipping: ${src}" >&2
    return 1
  fi

  mkdir -p "$(dirname "${dst}")"

  if [[ -d "${src}" ]]; then
    mkdir -p "${dst}"
    rsync "${rsync_args[@]}" "${src}/" "${dst}/"
  else
    rsync "${rsync_args[@]}" "${src}" "${dst}"
  fi
}

for arg in "$@"; do
  case "$arg" in
    status|pull|push)
      mode="$arg"
      ;;
    --dry-run)
      dry_run=1
      ;;
    --include-wallpaper)
      include_wallpaper=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if (( include_wallpaper )); then
  managed_paths+=( ".config/wallpaper" )
fi

if [[ ! -d "${payload_root}" ]]; then
  echo "payload/skel not found: ${payload_root}" >&2
  exit 1
fi

case "${mode}" in
  status)
    drift_found=0
    for rel in "${managed_paths[@]}"; do
      if ! compare_path "${rel}"; then
        drift_found=1
      fi
    done

    if (( drift_found )); then
      echo
      echo "Drift detected."
      exit 1
    fi

    echo
    echo "All managed paths match."
    ;;
  pull)
    require_cmd rsync
    echo "Syncing payload/skel -> \$HOME"
    for rel in "${managed_paths[@]}"; do
      sync_path "${payload_root}" "${HOME}" "${rel}" repo_to_local
    done
    ;;
  push)
    require_cmd rsync
    echo "Syncing \$HOME -> payload/skel"
    for rel in "${managed_paths[@]}"; do
      sync_path "${HOME}" "${payload_root}" "${rel}" local_to_repo
    done
    ;;
esac
