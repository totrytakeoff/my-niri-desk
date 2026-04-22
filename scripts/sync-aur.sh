#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aur_dir="${repo_root}/aur/my-niri-desk"

mkdir -p "${aur_dir}"
rm -rf "${aur_dir}/payload" "${aur_dir}/scripts"
mkdir -p "${aur_dir}/scripts"

cp -f "${repo_root}/PKGBUILD" "${aur_dir}/PKGBUILD"
cp -f "${repo_root}/.SRCINFO" "${aur_dir}/.SRCINFO"
cp -f "${repo_root}/my-niri-desk.install" "${aur_dir}/my-niri-desk.install"
cp -a "${repo_root}/payload" "${aur_dir}/payload"
cp -f "${repo_root}/scripts/my-niri-desk-apply" "${aur_dir}/scripts/my-niri-desk-apply"

echo "Synced AUR view:"
echo "  ${aur_dir}"
