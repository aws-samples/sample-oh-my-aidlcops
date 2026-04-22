#!/usr/bin/env bash
# install-kiro.sh
# Installs oh-my-aidlcops (OMA) plugins into the current user's ~/.kiro/ tree.
# POSIX-compatible bash; idempotent; safe to re-run.
#
# Kiro consumes skills as a flat set of directories (.kiro/skills/<plugin>/<skill>)
# and steering from .kiro/steering/. This script symlinks each SKILL.md source
# into place and surfaces any Kiro-specific sidecar metadata (kiro.meta.yaml).

set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
OMA_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OMA_OWNER="${OMA_OWNER:-devfloor9}"
KIRO_HOME="${KIRO_HOME:-$HOME/.kiro}"
MARKETPLACE_JSON="$OMA_REPO_DIR/.claude-plugin/marketplace.json"

SKILLS_LINKED=0
KIRO_META_FOUND=0

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
install-kiro.sh — Install oh-my-aidlcops (OMA) into ~/.kiro/

Usage:
    bash scripts/install-kiro.sh [--help]

Environment:
    OMA_OWNER    GitHub owner for the marketplace (default: devfloor9).
    KIRO_HOME    Target Kiro directory (default: $HOME/.kiro).

What it does:
    1. Create ~/.kiro/skills/<plugin>/<skill>/ symlinks for every skill in every
       plugin listed in .claude-plugin/marketplace.json.
    2. Symlink steering/ -> ~/.kiro/steering/.
    3. Emit a note for any SKILL.md that has a kiro.meta.yaml sidecar — Kiro
       reads those for trigger and context hints.

Dependencies: jq, bash 4+.
Idempotent — re-running refreshes stale symlinks only.
EOF
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '[install-kiro] %s\n' "$*"; }
warn() { printf '[install-kiro][warn] %s\n' "$*" >&2; }
die()  { printf '[install-kiro][error] %s\n' "$*" >&2; exit 1; }

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
# Install phases
# ---------------------------------------------------------------------------
install_skills() {
    [ -f "$MARKETPLACE_JSON" ] || die "marketplace.json not found at $MARKETPLACE_JSON"
    skills_target="$KIRO_HOME/skills"
    ensure_dir "$skills_target"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        plugin_skills="$OMA_REPO_DIR/plugins/$plugin/skills"
        if [ ! -d "$plugin_skills" ]; then
            log "no skills dir for $plugin (skipping)"
            continue
        fi
        plugin_target="$skills_target/$plugin"
        ensure_dir "$plugin_target"
        for skill_path in "$plugin_skills"/*/; do
            [ -d "$skill_path" ] || continue
            skill_name="$(basename "$skill_path")"
            dst="$plugin_target/$skill_name"
            if link_or_refresh "${skill_path%/}" "$dst"; then
                SKILLS_LINKED=$((SKILLS_LINKED + 1))
                log "skill linked: $plugin/$skill_name"
            fi
            if [ -f "$skill_path/kiro.meta.yaml" ]; then
                KIRO_META_FOUND=$((KIRO_META_FOUND + 1))
                log "  kiro.meta.yaml sidecar detected for $plugin/$skill_name"
            fi
        done
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

install_steering() {
    src="$OMA_REPO_DIR/steering"
    dst="$KIRO_HOME/steering"
    if [ ! -d "$src" ]; then
        warn "no steering/ directory, skipping"
        return 0
    fi
    if link_or_refresh "$src" "$dst"; then
        log "steering linked: $dst"
    fi
}

summary() {
    cat <<EOF

Installation complete.
    skills linked         : $SKILLS_LINKED
    kiro.meta.yaml found  : $KIRO_META_FOUND
EOF
    if [ "$KIRO_META_FOUND" -gt 0 ]; then
        cat <<'NOTE'

Note: kiro.meta.yaml sidecars contain Kiro-specific trigger and context hints.
Kiro will load them automatically alongside each SKILL.md.
NOTE
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac
    require jq
    log "OMA repo : $OMA_REPO_DIR"
    log "KIRO_HOME: $KIRO_HOME"
    log "OMA_OWNER: $OMA_OWNER"
    install_skills
    install_steering
    summary
}

main "$@"
