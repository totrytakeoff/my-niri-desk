#!/usr/bin/env bash
set -euo pipefail

SYSTEM_OOMD_DROPIN="/etc/systemd/oomd.conf.d/60-desktop-pressure.conf"
APP_SLICE_DROPIN="/etc/systemd/user/app.slice.d/60-desktop-oomd.conf"
BACKGROUND_SLICE_DROPIN="/etc/systemd/user/background.slice.d/60-desktop-oomd.conf"

SWAP_USED_LIMIT="${SWAP_USED_LIMIT:-75%}"
APP_MEMORY_HIGH="${APP_MEMORY_HIGH:-20G}"
APP_MEMORY_MAX="${APP_MEMORY_MAX:-24G}"
APP_PRESSURE_LIMIT="${APP_PRESSURE_LIMIT:-40%}"
APP_PRESSURE_DURATION="${APP_PRESSURE_DURATION:-10s}"
BACKGROUND_MEMORY_HIGH="${BACKGROUND_MEMORY_HIGH:-4G}"
BACKGROUND_MEMORY_MAX="${BACKGROUND_MEMORY_MAX:-6G}"
BACKGROUND_PRESSURE_LIMIT="${BACKGROUND_PRESSURE_LIMIT:-30%}"
BACKGROUND_PRESSURE_DURATION="${BACKGROUND_PRESSURE_DURATION:-10s}"
DEFAULT_PRESSURE_LIMIT="${DEFAULT_PRESSURE_LIMIT:-60%}"
DEFAULT_PRESSURE_DURATION="${DEFAULT_PRESSURE_DURATION:-20s}"

usage() {
    local prog
    prog="$(basename "$0")"
    cat <<EOF
Usage:
  ${prog} --dry-run
  ${prog} --apply
  ${prog} --revert
  ${prog} --status

Purpose:
  Configure a conservative desktop systemd-oomd policy:
    - app.slice: bound foreground application memory and enable oomd swap kills.
    - background.slice: use stricter bounds for background work.
    - session.slice: untouched, so compositor/session components are not made kill targets.

Tunables via environment variables:
  SWAP_USED_LIMIT=75%
  APP_MEMORY_HIGH=20G
  APP_MEMORY_MAX=24G
  APP_PRESSURE_LIMIT=40%
  APP_PRESSURE_DURATION=10s
  BACKGROUND_MEMORY_HIGH=4G
  BACKGROUND_MEMORY_MAX=6G
  BACKGROUND_PRESSURE_LIMIT=30%
  BACKGROUND_PRESSURE_DURATION=10s
  DEFAULT_PRESSURE_LIMIT=60%
  DEFAULT_PRESSURE_DURATION=20s

Notes:
  --apply writes /etc/systemd drop-ins and enables systemd-oomd.service.
  For the current login session, it also attempts runtime set-property on the
  user slices. If the user bus is unavailable, log out/in to load the drop-ins.
EOF
}

need_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

print_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        printf '\n## %s\n' "$path"
        sed -n '1,160p' "$path"
    else
        printf '\n## %s\n(absent)\n' "$path"
    fi
}

write_file() {
    local path="$1"
    local content="$2"
    install -d -m 0755 "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    chmod 0644 "$path"
}

system_oomd_content() {
    cat <<EOF
# Managed by configure-desktop-oomd.
# Earlier swap intervention for zram-only desktop sessions.
[OOM]
SwapUsedLimit=${SWAP_USED_LIMIT}
DefaultMemoryPressureLimit=${DEFAULT_PRESSURE_LIMIT}
DefaultMemoryPressureDurationSec=${DEFAULT_PRESSURE_DURATION}
EOF
}

app_slice_content() {
    cat <<EOF
# Managed by configure-desktop-oomd.
# Keep foreground desktop apps bounded so one workload cannot force global OOM.
[Slice]
MemoryAccounting=yes
MemoryHigh=${APP_MEMORY_HIGH}
MemoryMax=${APP_MEMORY_MAX}
ManagedOOMSwap=kill
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=${APP_PRESSURE_LIMIT}
ManagedOOMMemoryPressureDurationSec=${APP_PRESSURE_DURATION}
EOF
}

background_slice_content() {
    cat <<EOF
# Managed by configure-desktop-oomd.
# Background tasks should yield before interactive desktop apps.
[Slice]
MemoryAccounting=yes
MemoryHigh=${BACKGROUND_MEMORY_HIGH}
MemoryMax=${BACKGROUND_MEMORY_MAX}
ManagedOOMSwap=kill
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=${BACKGROUND_PRESSURE_LIMIT}
ManagedOOMMemoryPressureDurationSec=${BACKGROUND_PRESSURE_DURATION}
EOF
}

dry_run() {
    printf 'Would write:\n'
    printf '\n## %s\n%s\n' "$SYSTEM_OOMD_DROPIN" "$(system_oomd_content)"
    printf '\n## %s\n%s\n' "$APP_SLICE_DROPIN" "$(app_slice_content)"
    printf '\n## %s\n%s\n' "$BACKGROUND_SLICE_DROPIN" "$(background_slice_content)"
    cat <<'EOF'

Would then run:
  systemctl daemon-reload
  systemctl enable --now systemd-oomd.service
  systemctl restart systemd-oomd.service
  systemctl --user daemon-reload
  systemctl --user set-property --runtime app.slice ...
  systemctl --user set-property --runtime background.slice ...
EOF
}

apply_config() {
    need_root "$@"

    write_file "$SYSTEM_OOMD_DROPIN" "$(system_oomd_content)"
    write_file "$APP_SLICE_DROPIN" "$(app_slice_content)"
    write_file "$BACKGROUND_SLICE_DROPIN" "$(background_slice_content)"

    systemctl daemon-reload
    systemctl enable --now systemd-oomd.service
    systemctl restart systemd-oomd.service

    local target_user="${SUDO_USER:-}"
    if [[ -z "$target_user" && -n "${PKEXEC_UID:-}" ]]; then
        target_user="$(id -nu "$PKEXEC_UID" 2>/dev/null || true)"
    fi
    target_user="${target_user:-${USER:-}}"
    if [[ -n "$target_user" && "$target_user" != "root" ]]; then
        local uid
        uid="$(id -u "$target_user")"
        local bus="unix:path=/run/user/${uid}/bus"

        if [[ -S "/run/user/${uid}/bus" ]]; then
            if runuser -u "$target_user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" systemctl --user daemon-reload; then
                runuser -u "$target_user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" systemctl --user set-property --runtime app.slice \
                    MemoryAccounting=yes \
                    MemoryHigh="${APP_MEMORY_HIGH}" \
                    MemoryMax="${APP_MEMORY_MAX}" \
                    ManagedOOMSwap=kill \
                    ManagedOOMMemoryPressure=kill \
                    ManagedOOMMemoryPressureLimit="${APP_PRESSURE_LIMIT}" \
                    ManagedOOMMemoryPressureDurationSec="${APP_PRESSURE_DURATION}" || true
                runuser -u "$target_user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" systemctl --user set-property --runtime background.slice \
                    MemoryAccounting=yes \
                    MemoryHigh="${BACKGROUND_MEMORY_HIGH}" \
                    MemoryMax="${BACKGROUND_MEMORY_MAX}" \
                    ManagedOOMSwap=kill \
                    ManagedOOMMemoryPressure=kill \
                    ManagedOOMMemoryPressureLimit="${BACKGROUND_PRESSURE_LIMIT}" \
                    ManagedOOMMemoryPressureDurationSec="${BACKGROUND_PRESSURE_DURATION}" || true
            else
                printf 'Warning: could not reload %s user manager; log out/in to apply user slice drop-ins.\n' "$target_user" >&2
            fi
        else
            printf 'Warning: no user bus for %s; log out/in to apply user slice drop-ins.\n' "$target_user" >&2
        fi
    else
        printf 'Warning: could not identify non-root target user for runtime user-slice update.\n' >&2
    fi

    printf 'Applied desktop oomd drop-ins.\n'
    printf 'Check with: oomctl; systemctl status systemd-oomd.service\n'
}

revert_config() {
    need_root "$@"

    rm -f "$SYSTEM_OOMD_DROPIN" "$APP_SLICE_DROPIN" "$BACKGROUND_SLICE_DROPIN"
    rmdir --ignore-fail-on-non-empty \
        "$(dirname "$SYSTEM_OOMD_DROPIN")" \
        "$(dirname "$APP_SLICE_DROPIN")" \
        "$(dirname "$BACKGROUND_SLICE_DROPIN")" 2>/dev/null || true

    systemctl daemon-reload
    systemctl restart systemd-oomd.service 2>/dev/null || true

    local target_user="${SUDO_USER:-}"
    if [[ -z "$target_user" && -n "${PKEXEC_UID:-}" ]]; then
        target_user="$(id -nu "$PKEXEC_UID" 2>/dev/null || true)"
    fi
    target_user="${target_user:-${USER:-}}"
    if [[ -n "$target_user" && "$target_user" != "root" ]]; then
        local uid
        uid="$(id -u "$target_user")"
        local bus="unix:path=/run/user/${uid}/bus"
        if [[ -S "/run/user/${uid}/bus" ]]; then
            runuser -u "$target_user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" systemctl --user daemon-reload || true
            runuser -u "$target_user" -- env DBUS_SESSION_BUS_ADDRESS="$bus" systemctl --user revert app.slice background.slice || true
        fi
    fi

    printf 'Reverted desktop oomd drop-ins.\n'
}

status_config() {
    print_file "$SYSTEM_OOMD_DROPIN"
    print_file "$APP_SLICE_DROPIN"
    print_file "$BACKGROUND_SLICE_DROPIN"

    printf '\n## systemd-oomd.service\n'
    systemctl --no-pager --full status systemd-oomd.service || true

    if command -v oomctl >/dev/null 2>&1; then
        printf '\n## oomctl\n'
        oomctl || true
    fi
}

main() {
    local command="${1:-}"
    case "$command" in
        --dry-run)
            dry_run
            ;;
        --apply)
            apply_config "$@"
            ;;
        --revert)
            revert_config "$@"
            ;;
        --status)
            status_config
            ;;
        -h|--help|"")
            usage
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$command" >&2
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
