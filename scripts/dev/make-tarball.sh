#!/usr/bin/env bash
# scripts/dev/make-tarball.sh — produce oh-my-aidlcops-<ver>.tar.gz.
#
# Usage:
#   bash scripts/dev/make-tarball.sh [--out DIR] [--version vX.Y.Z]
#
# Defaults:
#   --version = .claude-plugin/marketplace.json -> metadata.version (prefixed with v)
#   --out     = ./dist
#
# Excludes ephemeral dirs (node_modules, .venv*, build, docs build output, .omc,
# .omao session/logs/research). Includes exactly what a clean install needs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$REPO_ROOT/dist"
VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --out)      OUT_DIR="$2"; shift 2 ;;
        --version)  VERSION="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'unknown flag: %s\n' "$1" >&2; exit 64 ;;
    esac
done

if [ -z "$VERSION" ]; then
    raw="$(jq -r '.metadata.version' "$REPO_ROOT/.claude-plugin/marketplace.json")"
    VERSION="v${raw}"
fi

mkdir -p "$OUT_DIR"
tarball="$OUT_DIR/oh-my-aidlcops-${VERSION}.tar.gz"

cd "$REPO_ROOT"
tar \
    --exclude='./.git' \
    --exclude='./.github/workflows/gitlab-mirror.yml' \
    --exclude='./node_modules' \
    --exclude='./.venv*' \
    --exclude='./.pytest_cache' \
    --exclude='./.ruff_cache' \
    --exclude='./.mypy_cache' \
    --exclude='./.claude-plugin/.installed' \
    --exclude='./.omc' \
    --exclude='./.omao/state' \
    --exclude='./.omao/logs' \
    --exclude='./.omao/research' \
    --exclude='./.omao/plans' \
    --exclude='./.omao/notepad.md' \
    --exclude='./.omao/project-memory.json' \
    --exclude='./docs/node_modules' \
    --exclude='./docs/build' \
    --exclude='./docs/.docusaurus' \
    --exclude='./dist' \
    --exclude='./.venv-oma*' \
    --exclude='./evals/_runs' \
    --exclude='./CLAUDE.md' \
    --exclude='**/CLAUDE.md' \
    -czf "$tarball" .

sha="$(shasum -a 256 "$tarball" | awk '{print $1}')"
printf '%s  %s\n' "$sha" "$(basename "$tarball")" > "$tarball.sha256"

printf 'tarball : %s\n' "$tarball"
printf 'sha256  : %s\n' "$sha"
printf 'size    : %s\n' "$(du -h "$tarball" | awk '{print $1}')"
