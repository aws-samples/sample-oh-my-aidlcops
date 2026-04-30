#!/usr/bin/env bash
# install-aidlc.sh
# Clones awslabs/aidlc-workflows into $HOME/.aidlc and symlinks the OMA opt-in
# extensions into the appropriate aidlc-rule-details/extensions/ directory.
# Idempotent; safe to re-run.

set -euo pipefail
# Note: IFS is kept at its default here; `while IFS= read -r` below sets it locally per-loop.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
OMA_REPO_DIR="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
OMA_OWNER="${OMA_OWNER:-aws-samples}"
AIDLC_DIR="${AIDLC_DIR:-$HOME/.aidlc}"
AIDLC_REPO_URL="${AIDLC_REPO_URL:-https://github.com/awslabs/aidlc-workflows.git}"
MARKETPLACE_JSON="$OMA_REPO_DIR/.claude-plugin/marketplace.json"

EXTENSIONS_LINKED=0

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
install-aidlc.sh — Clone awslabs/aidlc-workflows and wire OMA opt-in extensions.

Usage:
    bash scripts/install-aidlc.sh [--help]

Environment:
    OMA_OWNER       GitHub owner for the marketplace (default: aws-samples).
    AIDLC_DIR       Target directory for aidlc-workflows (default: $HOME/.aidlc).
    AIDLC_REPO_URL  Upstream repo (default: awslabs/aidlc-workflows).

What it does:
    1. git clone awslabs/aidlc-workflows into $AIDLC_DIR, or git pull if present.
    2. For every plugin listed in marketplace.json, walk
       plugins/<name>/aidlc-rule-details/extensions/*.opt-in.md and symlink each
       file into $AIDLC_DIR/aidlc-rules/aidlc-rule-details/extensions/.

Dependencies: git, jq.
Safe to re-run: stale symlinks are refreshed, existing files are left alone.
EOF
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '[install-aidlc] %s\n' "$*"; }
warn() { printf '[install-aidlc][warn] %s\n' "$*" >&2; }
die()  { printf '[install-aidlc][error] %s\n' "$*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 (install it and re-run)"
}

ensure_dir() {
    [ -d "$1" ] || mkdir -p "$1"
}

link_or_refresh() {
    src="$1"; dst="$2"
    [ -e "$src" ] || { warn "source missing, skipping: $src"; return 1; }
    if [ -L "$dst" ]; then
        current="$(readlink "$dst")"
        if [ "$current" = "$src" ]; then
            return 0
        fi
        rm "$dst"
    elif [ -e "$dst" ]; then
        warn "refusing to replace non-symlink: $dst"
        return 1
    fi
    ensure_dir "$(dirname "$dst")"
    ln -s "$src" "$dst"
}

# ---------------------------------------------------------------------------
# Clone / update aidlc-workflows
# ---------------------------------------------------------------------------
sync_aidlc_repo() {
    if [ -d "$AIDLC_DIR/.git" ]; then
        log "updating aidlc-workflows in $AIDLC_DIR"
        git -C "$AIDLC_DIR" fetch --depth=1 origin HEAD >/dev/null 2>&1 || warn "git fetch failed (continuing)"
        git -C "$AIDLC_DIR" pull --ff-only >/dev/null 2>&1 || warn "git pull failed (continuing with existing copy)"
    elif [ -d "$AIDLC_DIR" ]; then
        warn "$AIDLC_DIR exists but is not a git checkout; skipping clone"
    else
        log "cloning $AIDLC_REPO_URL into $AIDLC_DIR"
        git clone --depth=1 "$AIDLC_REPO_URL" "$AIDLC_DIR"
    fi
}

# Determine the target extensions directory inside aidlc-workflows.
# Preference order:
#   1. $AIDLC_DIR/aidlc-rules/aidlc-rule-details/extensions/
#   2. $AIDLC_DIR/aidlc-rule-details/extensions/
#   3. First directory matching */aidlc-rule-details/extensions/ under $AIDLC_DIR
target_extensions_dir() {
    for candidate in \
        "$AIDLC_DIR/aidlc-rules/aidlc-rule-details/extensions" \
        "$AIDLC_DIR/aidlc-rule-details/extensions"; do
        if [ -d "$(dirname "$candidate")" ]; then
            echo "$candidate"
            return 0
        fi
    done
    match="$(find "$AIDLC_DIR" -type d -path '*/aidlc-rule-details/extensions' -print -quit 2>/dev/null || true)"
    if [ -n "$match" ]; then
        echo "$match"
        return 0
    fi
    # Fallback: create the canonical path.
    echo "$AIDLC_DIR/aidlc-rules/aidlc-rule-details/extensions"
}

# ---------------------------------------------------------------------------
# Link OMA opt-in extensions
# ---------------------------------------------------------------------------
install_extensions() {
    [ -f "$MARKETPLACE_JSON" ] || die "marketplace.json not found at $MARKETPLACE_JSON"
    target_dir="$(target_extensions_dir)"
    ensure_dir "$target_dir"
    log "extensions target: $target_dir"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        ext_dir="$OMA_REPO_DIR/plugins/$plugin/aidlc-rule-details/extensions"
        [ -d "$ext_dir" ] || continue
        for ext_file in "$ext_dir"/*.opt-in.md; do
            [ -e "$ext_file" ] || continue
            file_name="$(basename "$ext_file")"
            dst="$target_dir/$file_name"
            if link_or_refresh "$ext_file" "$dst"; then
                EXTENSIONS_LINKED=$((EXTENSIONS_LINKED + 1))
                log "extension linked: $plugin/$file_name"
            fi
        done
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

summary() {
    cat <<EOF

Installation complete.
    aidlc-workflows at   : $AIDLC_DIR
    opt-in extensions    : $EXTENSIONS_LINKED linked
EOF
    if [ "$EXTENSIONS_LINKED" -eq 0 ]; then
        log "(no opt-in extensions present yet — plugins will ship them in a later release)"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac
    require git
    require jq
    log "OMA repo : $OMA_REPO_DIR"
    log "AIDLC_DIR: $AIDLC_DIR"
    log "OMA_OWNER: $OMA_OWNER"
    sync_aidlc_repo
    install_extensions
    summary
}

main "$@"
