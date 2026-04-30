#!/usr/bin/env bash
# scripts/oma/compile.sh — thin wrapper around `python -m tools.oma_compile`.
set -euo pipefail
# shellcheck disable=SC1091
. "${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/lib/log.sh"

repo_root="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$repo_root"

if ! command -v python3 >/dev/null 2>&1; then
    die "oma compile needs python3 (not found in PATH)"
fi

# Default to --all when no args.
if [ "$#" -eq 0 ]; then
    set -- --all
fi

exec python3 -m tools.oma_compile "$@"
