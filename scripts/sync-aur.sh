#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aur_dir="${repo_root}/aur/my-niri-desk"

mkdir -p "${aur_dir}"
cp -f "${repo_root}/my-niri-desk.install" "${aur_dir}/my-niri-desk.install"

if grep -q 'REPLACE_ME_' "${aur_dir}/PKGBUILD"; then
  echo "AUR PKGBUILD still contains placeholder checksums." >&2
  echo "Update aur/my-niri-desk/PKGBUILD first." >&2
  exit 1
fi

( cd "${aur_dir}" && makepkg --printsrcinfo > .SRCINFO )

echo "Synced AUR view:"
echo "  ${aur_dir}"
