#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/local/aur/repo" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aur_view="${repo_root}/aur/my-niri-desk"
target_repo="$1"

"${repo_root}/scripts/sync-aur.sh"

if [[ ! -d "${target_repo}/.git" ]]; then
  echo "Target is not a git repository: ${target_repo}" >&2
  exit 1
fi

find "${target_repo}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -f "${aur_view}/PKGBUILD" "${target_repo}/PKGBUILD"
cp -f "${aur_view}/.SRCINFO" "${target_repo}/.SRCINFO"
cp -f "${aur_view}/my-niri-desk.install" "${target_repo}/my-niri-desk.install"

cd "${target_repo}"
git add .

if git diff --cached --quiet; then
  echo "No AUR changes to commit."
  exit 0
fi

git commit -m "Update my-niri-desk package"

cat <<'EOF'
Local AUR repository updated.

Next:
  git push
EOF
