#!/usr/bin/env bash
# scripts/oma/status.sh — stub. Filled in alongside P2/P3.
set -euo pipefail
# shellcheck disable=SC1091
. "${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/lib/log.sh"

profile=".omao/profile.yaml"
if [ ! -f "$profile" ]; then
    warn "no .omao/profile.yaml in $(pwd) — run \`oma setup\` first."
    exit 1
fi

step "profile: $profile"
if command -v yq >/dev/null 2>&1; then
    yq '{version, harness, aws, aidlc, approval, budgets, observability}' "$profile"
else
    cat "$profile"
fi
