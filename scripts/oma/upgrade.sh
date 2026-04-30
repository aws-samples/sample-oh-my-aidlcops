#!/usr/bin/env bash
# scripts/oma/upgrade.sh — git pull + re-run setup --migrate for clone installs.
set -euo pipefail
# shellcheck disable=SC1091
. "${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/lib/log.sh"

repo_root="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [ ! -d "$repo_root/.git" ]; then
    die "oma upgrade only works for clone installs (missing $repo_root/.git)."
fi

step "git pull in $repo_root"
git -C "$repo_root" pull --ff-only

step "re-run setup --migrate"
exec bash "$repo_root/scripts/oma/setup.sh" --migrate "$@"
