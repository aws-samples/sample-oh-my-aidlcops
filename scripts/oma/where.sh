#!/usr/bin/env bash
# scripts/oma/where.sh — print the OMA install root.
#
# Useful when users need the raw path (rarely, after `oma init` / `oma
# setup` exist). Also prints the detected harness settings + version so a
# single command gives an orientation snapshot.

set -euo pipefail
REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [ "${1:-}" = --json ]; then
    jq -n \
        --arg repo_root "$REPO_ROOT" \
        --arg bin "$(command -v oma 2>/dev/null || echo '')" \
        --arg version "${OMA_VERSION:-unknown}" \
        '{repo_root:$repo_root, bin:$bin, version:$version, scripts:"\($repo_root)/scripts", hooks:"\($repo_root)/hooks", plugins:"\($repo_root)/plugins"}'
    exit 0
fi

printf 'OMA install root : %s\n' "$REPO_ROOT"
printf 'oma binary       : %s\n' "$(command -v oma 2>/dev/null || echo '(not on PATH)')"
printf 'OMA version      : %s\n' "${OMA_VERSION:-unknown}"
printf '\nKey subdirectories:\n'
printf '  scripts  : %s/scripts\n' "$REPO_ROOT"
printf '  hooks    : %s/hooks\n'   "$REPO_ROOT"
printf '  plugins  : %s/plugins\n' "$REPO_ROOT"
printf '  schemas  : %s/schemas\n' "$REPO_ROOT"
printf '  templates: %s/templates\n' "$REPO_ROOT"
