#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
payload_root="${repo_root}/payload/skel"
temp_root="$(mktemp -d)"

mode="status"
dry_run=0
include_wallpaper=0
filters=()

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
  ./scripts/sync-local-config.sh [status|diff|pull|push] [PATH ...] [--dry-run] [--include-wallpaper]

Modes:
  status    Compare local config against payload/skel and print drift. Default.
  diff      Show unified diffs from payload/skel to local config.
  pull      Sync payload/skel -> $HOME for managed paths. Deletes extra local files.
  push      Sync $HOME -> payload/skel for managed paths. Deletes extra repo files.

Options:
  PATH                 Limit status/diff to a managed path or file.
  --dry-run            Show what would change without writing.
  --include-wallpaper  Include .config/wallpaper in compare/sync operations.
  -h, --help           Show this help.

Notes:
  - This is a maintainer helper, not an end-user setup script.
  - PATH filters are supported for status/diff only.
  - PATH may be a full managed path like .config/niri/config.kdl or a shortcut like niri/config.kdl.
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
    ".config/niri")
      printf '%s\n' "__pycache__"
      ;;
    ".config/quickshell")
      printf '%s\n' "__pycache__"
      ;;
    ".config/fcitx5")
      printf '%s\n' "cached_layouts" "notifications.conf_*"
      ;;
  esac
}

normalize_filter() {
  local filter="$1"

  filter="${filter%/}"
  filter="${filter#${HOME}/}"
  filter="${filter#${payload_root}/}"
  filter="${filter#payload/skel/}"
  filter="${filter#repo/}"
  filter="${filter#local/}"
  filter="${filter#./}"

  case "${filter}" in
    .config/*|.local/*)
      printf '%s\n' "${filter}"
      ;;
    *)
      printf '.config/%s\n' "${filter}"
      ;;
  esac
}

managed_root_for_filter() {
  local filter_rel="$1"
  local managed_rel

  for managed_rel in "${managed_paths[@]}"; do
    if [[ "${filter_rel}" == "${managed_rel}" || "${filter_rel}" == "${managed_rel}/"* ]]; then
      printf '%s\n' "${managed_rel}"
      return 0
    fi
  done

  return 1
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

prepare_diff_path() {
  local source_root="$1"
  local rel="$2"
  local direction="$3"
  local label="$4"
  local src="${source_root}/${rel}"
  local prepared="${temp_root}/${label}/${rel}"
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
  compare_path_target "${rel}" "${rel}"
}

compare_path_target() {
  local rel="$1"
  local target_rel="$2"
  local local_path="${HOME}/${rel}"
  local repo_path="${payload_root}/${rel}"
  local local_target_path="${HOME}/${target_rel}"
  local repo_target_path="${payload_root}/${target_rel}"
  local prepared_local_path
  local prepared_repo_path
  local -a diff_args=( -rq )
  local -a excludes=()

  if [[ ! -e "${local_target_path}" && ! -e "${repo_target_path}" ]]; then
    return 0
  fi

  if [[ ! -e "${repo_target_path}" ]]; then
    echo "[repo-missing] ${target_rel}"
    return 1
  fi

  if [[ ! -e "${local_target_path}" ]]; then
    echo "[local-missing] ${target_rel}"
    return 1
  fi

  prepared_repo_path="$(prepare_diff_path "${payload_root}" "${rel}" repo_to_local repo)"
  prepared_local_path="$(prepare_diff_path "${HOME}" "${rel}" local_view local)"
  mapfile -t excludes < <(path_excludes "${rel}")
  for pattern in "${excludes[@]}"; do
    diff_args+=( "--exclude=${pattern}" )
  done

  if diff "${diff_args[@]}" "${temp_root}/repo/${target_rel}" "${temp_root}/local/${target_rel}" >/dev/null 2>&1; then
    echo "[ok] ${target_rel}"
    return 0
  fi

  echo "[drift] ${target_rel}"
  (
    cd "${temp_root}"
    diff "${diff_args[@]}" "repo/${target_rel}" "local/${target_rel}" || true
  )
  return 1
}

diff_path() {
  local rel="$1"
  diff_path_target "${rel}" "${rel}"
}

diff_path_target() {
  local rel="$1"
  local target_rel="$2"
  local local_path="${HOME}/${rel}"
  local repo_path="${payload_root}/${rel}"
  local local_target_path="${HOME}/${target_rel}"
  local repo_target_path="${payload_root}/${target_rel}"
  local prepared_local_path
  local prepared_repo_path
  local -a diff_args=( -ruN )
  local -a excludes=()

  if [[ ! -e "${local_target_path}" && ! -e "${repo_target_path}" ]]; then
    return 0
  fi

  if [[ ! -e "${repo_target_path}" ]]; then
    echo "===== ${target_rel} (repo missing) ====="
    prepared_local_path="$(prepare_diff_path "${HOME}" "${rel}" local_view local)"
    (
      cd "${temp_root}"
      diff -ruN /dev/null "local/${target_rel}" || true
    )
    return 1
  fi

  if [[ ! -e "${local_target_path}" ]]; then
    echo "===== ${target_rel} (local missing) ====="
    prepared_repo_path="$(prepare_diff_path "${payload_root}" "${rel}" repo_to_local repo)"
    (
      cd "${temp_root}"
      diff -ruN "repo/${target_rel}" /dev/null || true
    )
    return 1
  fi

  prepared_repo_path="$(prepare_diff_path "${payload_root}" "${rel}" repo_to_local repo)"
  prepared_local_path="$(prepare_diff_path "${HOME}" "${rel}" local_view local)"
  mapfile -t excludes < <(path_excludes "${rel}")
  for pattern in "${excludes[@]}"; do
    diff_args+=( "--exclude=${pattern}" )
  done

  if diff "${diff_args[@]}" "${temp_root}/repo/${target_rel}" "${temp_root}/local/${target_rel}" >/dev/null 2>&1; then
    return 0
  fi

  echo "===== ${target_rel} ====="
  (
    cd "${temp_root}"
    diff "${diff_args[@]}" "repo/${target_rel}" "local/${target_rel}" || true
  )
  return 1
}

sync_path() {
  local source_root="$1"
  local target_root="$2"
  local rel="$3"
  local direction="$4"
  local src
  local dst="${target_root}/${rel}"
  local -a rsync_args=( -rl --checksum --delete --itemize-changes )
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
    status|diff|pull|push)
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
      if [[ "$arg" == -* ]]; then
        echo "Unknown argument: $arg" >&2
        usage >&2
        exit 1
      fi
      filters+=( "$arg" )
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

if (( ${#filters[@]} > 0 )) && [[ "${mode}" != "status" && "${mode}" != "diff" ]]; then
  echo "PATH filters are only supported for status and diff." >&2
  exit 1
fi

case "${mode}" in
  status)
    drift_found=0
    if (( ${#filters[@]} > 0 )); then
      for filter in "${filters[@]}"; do
        filter_rel="$(normalize_filter "${filter}")"
        if ! rel="$(managed_root_for_filter "${filter_rel}")"; then
          echo "Path is not managed: ${filter}" >&2
          exit 1
        fi
        if ! compare_path_target "${rel}" "${filter_rel}"; then
          drift_found=1
        fi
      done
    else
      for rel in "${managed_paths[@]}"; do
        if ! compare_path "${rel}"; then
          drift_found=1
        fi
      done
    fi

    if (( drift_found )); then
      echo
      echo "Drift detected."
      exit 1
    fi

    echo
    echo "All managed paths match."
    ;;
  diff)
    drift_found=0
    if (( ${#filters[@]} > 0 )); then
      for filter in "${filters[@]}"; do
        filter_rel="$(normalize_filter "${filter}")"
        if ! rel="$(managed_root_for_filter "${filter_rel}")"; then
          echo "Path is not managed: ${filter}" >&2
          exit 1
        fi
        if ! diff_path_target "${rel}" "${filter_rel}"; then
          drift_found=1
        fi
      done
    else
      for rel in "${managed_paths[@]}"; do
        if ! diff_path "${rel}"; then
          drift_found=1
        fi
      done
    fi

    if (( drift_found )); then
      exit 1
    fi
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
