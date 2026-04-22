#!/usr/bin/env bash
# init-omao.sh
# Initializes a .omao/ workspace in the user's project directory.
# Idempotent. Refuses to overwrite an existing .omao/ unless --force is given.

set -euo pipefail
# IFS is left at the default; the script does not rely on word-splitting.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
OMA_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
FORCE=0

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
init-omao.sh — Initialize a .omao/ workspace in the current project.

Usage:
    bash <oma-repo>/scripts/init-omao.sh [--help] [--force] [--dir PATH]

Options:
    --force       Overwrite an existing .omao/ directory.
    --dir PATH    Target directory (default: current working directory).

What it creates:
    .omao/plans/                   AIDLC artifacts (spec, design, ADR, stories).
    .omao/state/                   Session checkpoints, in-flight Tier-0 mode.
    .omao/notepad.md               Working memo (seeded with empty sections).
    .omao/project-memory.json      Project-level durable facts.
    .omao/triggers.json            Keyword triggers (copied from OMA repo).

Safe by default — refuses to overwrite an existing .omao/ unless --force.
EOF
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '[init-omao] %s\n' "$*"; }
warn() { printf '[init-omao][warn] %s\n' "$*" >&2; }
die()  { printf '[init-omao][error] %s\n' "$*" >&2; exit 1; }

iso_now() {
    # UTC timestamp, portable across BSD/GNU date.
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --force)   FORCE=1; shift ;;
        --dir)     PROJECT_DIR="$2"; shift 2 ;;
        *)         die "unknown argument: $1 (try --help)" ;;
    esac
done

OMAO_DIR="$PROJECT_DIR/.omao"

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[ -d "$PROJECT_DIR" ] || die "project directory does not exist: $PROJECT_DIR"

if [ -d "$OMAO_DIR" ] && [ "$FORCE" -eq 0 ]; then
    die ".omao/ already exists at $OMAO_DIR (use --force to overwrite)"
fi

# ---------------------------------------------------------------------------
# Scaffold
# ---------------------------------------------------------------------------
log "target: $OMAO_DIR"
mkdir -p "$OMAO_DIR/plans" "$OMAO_DIR/state"

# notepad.md — three empty sections matching the OMC convention.
notepad="$OMAO_DIR/notepad.md"
if [ "$FORCE" -eq 1 ] || [ ! -f "$notepad" ]; then
    cat > "$notepad" <<'EOF'
# OMAO Notepad

Working memo for the current project. Sections are merged by OMA skills and
preserved across sessions. Keep entries short — link out to plans/ or docs
for detail.

## Working

<!-- In-progress notes, hypotheses, and scratch. Auto-pruned after 7 days. -->

## Priority

<!-- High-signal items flagged by the user or a Tier-0 workflow. -->

## Manual

<!-- Hand-authored durable notes. Never auto-pruned. -->
EOF
    log "wrote: $notepad"
fi

# project-memory.json — seeded with mandatory keys.
memory="$OMAO_DIR/project-memory.json"
if [ "$FORCE" -eq 1 ] || [ ! -f "$memory" ]; then
    created_at="$(iso_now)"
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg created "$created_at" '{
            created: $created,
            project_type: "unknown",
            aidlc_phase: null,
            active_mode: null
        }' > "$memory"
    else
        cat > "$memory" <<EOF
{
  "created": "$created_at",
  "project_type": "unknown",
  "aidlc_phase": null,
  "active_mode": null
}
EOF
    fi
    log "wrote: $memory"
fi

# triggers.json — copy from OMA repo if present, else write an empty registry.
triggers_dst="$OMAO_DIR/triggers.json"
triggers_src="$OMA_REPO_DIR/.omao/triggers.json"
if [ "$FORCE" -eq 1 ] || [ ! -f "$triggers_dst" ]; then
    if [ -f "$triggers_src" ]; then
        cp "$triggers_src" "$triggers_dst"
        log "copied: $triggers_src -> $triggers_dst"
    else
        cat > "$triggers_dst" <<'EOF'
{
  "version": "0.1.0",
  "triggers": []
}
EOF
        log "wrote stub: $triggers_dst (OMA repo has no triggers.json yet)"
    fi
fi

log "done. Created .omao/ at $OMAO_DIR"
