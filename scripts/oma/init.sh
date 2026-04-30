#!/usr/bin/env bash
# scripts/oma/init.sh — thin wrapper around scripts/init-omao.sh.
#
# Usage:
#   oma init [--force] [--dir PATH]
#
# Users do not need to know where the OMA install root lives. `oma init`
# resolves $OMA_REPO_ROOT (set by bin/oma dispatcher) and invokes
# init-omao.sh for them. The resulting .omao/ is created in the current
# working directory (or --dir).

set -euo pipefail
REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"

target_script="$REPO_ROOT/scripts/init-omao.sh"
[ -f "$target_script" ] || die "init-omao.sh not found at $target_script"

case "${1:-}" in
    -h|--help)
        cat <<'EOF'
oma init — scaffold .omao/ in the current project directory.

Usage:
    oma init [--force] [--dir PATH]

Options:
    --force       Overwrite an existing .omao/ directory.
    --dir PATH    Target directory (default: current working directory).

Creates:
    .omao/plans/                 AIDLC artifacts (spec, design, ADR, stories)
    .omao/state/                 Session checkpoints, in-flight Tier-0 mode
    .omao/notepad.md             Working memo
    .omao/project-memory.json    Project durable facts
    .omao/triggers.json          Keyword trigger catalog

Safe by default — refuses to overwrite an existing .omao/ unless --force.
EOF
        exit 0
        ;;
esac

step "oma init — scaffolding .omao/"
exec bash "$target_script" "$@"
