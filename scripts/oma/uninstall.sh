#!/usr/bin/env bash
# scripts/oma/uninstall.sh — stub. Filled in by P8.
set -euo pipefail
# shellcheck disable=SC1091
. "${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/lib/log.sh"

warn "oma uninstall is not yet implemented. Manual steps:"
warn "  rm ~/.claude/plugins/{agentic-platform,agenticops,aidlc-inception,aidlc-construction,modernization}"
warn "  rm ~/.claude/commands/oma"
warn "  edit ~/.claude/settings.json to drop OMA hooks + MCP entries"
warn "  rm ~/.local/bin/oma"
exit 78
