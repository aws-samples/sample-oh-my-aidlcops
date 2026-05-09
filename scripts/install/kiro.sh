#!/usr/bin/env bash
# install-kiro.sh
# Installs oh-my-aidlcops (OMA) plugins into the current user's ~/.kiro/ tree.
# POSIX-compatible bash; idempotent; safe to re-run.
#
# Kiro consumes skills as a flat set of directories (.kiro/skills/<plugin>/<skill>)
# and steering from .kiro/steering/. This script symlinks each SKILL.md source
# into place and surfaces any Kiro-specific sidecar metadata (kiro.meta.yaml).

set -euo pipefail
# IFS kept at default; local `IFS=` is set per `read` loop below.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
OMA_REPO_DIR="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
OMA_OWNER="${OMA_OWNER:-aws-samples}"
KIRO_HOME="${KIRO_HOME:-$HOME/.kiro}"
MARKETPLACE_JSON="$OMA_REPO_DIR/.claude-plugin/marketplace.json"

SKILLS_LINKED=0
KIRO_META_FOUND=0
GUIDES_LINKED=0
AGENTS_LINKED=0
SETTINGS_INSTALLED=0
PERMISSIONS_APPLIED=0
PERMISSIONS_ENV=""
SKIP_PERMISSIONS="${OMA_SKIP_PERMISSIONS:-0}"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
install-kiro.sh — Install oh-my-aidlcops (OMA) into ~/.kiro/

Usage:
    bash scripts/install-kiro.sh [--help] [--skip-permissions]

Environment:
    OMA_OWNER             GitHub owner for the marketplace (default: aws-samples).
    KIRO_HOME             Target Kiro directory (default: $HOME/.kiro).
    OMA_PROJECT_DIR       Project that holds .omao/profile.yaml. Used to pick
                          the permission template (default: $PWD).
    OMA_SKIP_PERMISSIONS  Set to 1 to skip the install_permissions step.
    OMA_PERMISSIONS_ENV   Override the env (sandbox/staging/prod).

What it does:
    1. Create ~/.kiro/skills/<plugin>/<skill>/ symlinks for every skill in every
       plugin listed in .claude-plugin/marketplace.json.
    2. Symlink steering/ -> ~/.kiro/steering/.
    3. Symlink plugin guides/ -> ~/.kiro/guides/<plugin>/ (stage-gated safety-critical content).
    4. Symlink plugin kiro-agents/*.json -> ~/.kiro/agents/ (Kiro agent configurations).
    5. Install default settings/cli.json template if not present.
    6. Emit a note for any SKILL.md that has a kiro.meta.yaml sidecar — Kiro
       reads those for trigger and context hints.
    7. Apply env-scoped autoApprove from templates/permissions/ to
       ~/.kiro/settings/cli.json and every linked agent.json (safe overlay).

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
        # Walk one level deep, but if a child has no SKILL.md it is a
        # grouping directory (e.g. aidlc/skills/inception/) and we
        # recurse one more level to find the real skills inside.
        for skill_path in "$plugin_skills"/*/; do
            [ -d "$skill_path" ] || continue
            skill_name="$(basename "$skill_path")"
            if [ -f "$skill_path/SKILL.md" ]; then
                dst="$plugin_target/$skill_name"
                if link_or_refresh "${skill_path%/}" "$dst"; then
                    SKILLS_LINKED=$((SKILLS_LINKED + 1))
                    log "skill linked: $plugin/$skill_name"
                fi
                if [ -f "$skill_path/kiro.meta.yaml" ]; then
                    KIRO_META_FOUND=$((KIRO_META_FOUND + 1))
                    log "  kiro.meta.yaml sidecar detected for $plugin/$skill_name"
                fi
                continue
            fi
            # Grouping directory: descend one level and link each
            # inner skill as <plugin>/<group>/<skill>.
            group_name="$skill_name"
            group_target="$plugin_target/$group_name"
            ensure_dir "$group_target"
            for inner_path in "$skill_path"*/; do
                [ -d "$inner_path" ] || continue
                inner_name="$(basename "$inner_path")"
                dst="$group_target/$inner_name"
                if link_or_refresh "${inner_path%/}" "$dst"; then
                    SKILLS_LINKED=$((SKILLS_LINKED + 1))
                    log "skill linked: $plugin/$group_name/$inner_name"
                fi
                if [ -f "$inner_path/kiro.meta.yaml" ]; then
                    KIRO_META_FOUND=$((KIRO_META_FOUND + 1))
                    log "  kiro.meta.yaml sidecar detected for $plugin/$group_name/$inner_name"
                fi
            done
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

install_guides() {
    [ -f "$MARKETPLACE_JSON" ] || die "marketplace.json not found at $MARKETPLACE_JSON"
    guides_target="$KIRO_HOME/guides"
    ensure_dir "$guides_target"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        plugin_guides="$OMA_REPO_DIR/plugins/$plugin/guides"
        if [ ! -d "$plugin_guides" ]; then
            continue
        fi
        plugin_guides_target="$guides_target/$plugin"
        if link_or_refresh "$plugin_guides" "$plugin_guides_target"; then
            GUIDES_LINKED=$((GUIDES_LINKED + 1))
            log "guides linked: $plugin"
        fi
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

install_agents() {
    [ -f "$MARKETPLACE_JSON" ] || die "marketplace.json not found at $MARKETPLACE_JSON"
    agents_target="$KIRO_HOME/agents"
    ensure_dir "$agents_target"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        plugin_agents="$OMA_REPO_DIR/plugins/$plugin/kiro-agents"
        if [ ! -d "$plugin_agents" ]; then
            continue
        fi
        for agent_file in "$plugin_agents"/*.json; do
            [ -f "$agent_file" ] || continue
            agent_name="$(basename "$agent_file")"
            dst="$agents_target/$agent_name"
            if link_or_refresh "$agent_file" "$dst"; then
                AGENTS_LINKED=$((AGENTS_LINKED + 1))
                log "agent linked: $agent_name"
            fi
        done
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

install_settings() {
    settings_target="$KIRO_HOME/settings"
    cli_json="$settings_target/cli.json"
    template="$OMA_REPO_DIR/scripts/kiro-cli.template.json"

    if [ -f "$cli_json" ]; then
        return 0
    fi

    if [ ! -f "$template" ]; then
        warn "settings template not found at $template, skipping"
        return 0
    fi

    ensure_dir "$settings_target"
    cp "$template" "$cli_json"
    SETTINGS_INSTALLED=1
    log "settings installed: $cli_json"
}

# Apply env-scoped autoApprove from templates/permissions/ to:
#   - ~/.kiro/settings/cli.json     (global default)
#   - ~/.kiro/agents/*.agent.json   (per-agent, only the OMA-installed ones)
#
# Kiro has no permissions.deny list — it relies on autoApprove gates plus the
# `tools` whitelist on each agent profile. We tighten autoApprove to whatever
# the resolved template specifies; we do NOT touch the `tools` list because
# that risks disabling MCP servers Kiro itself relies on.
#
# Resolved deny.bash / deny.edit / deny.write / deny.mcp patterns are mirrored
# into agent.json `_meta.oma_permissions_deny` so they are auditable from the
# Kiro side even though Kiro does not enforce them as a permission gate.
install_permissions() {
    if [ "$SKIP_PERMISSIONS" = 1 ]; then
        log "permissions: skipped (OMA_SKIP_PERMISSIONS=1)"
        return 0
    fi

    # shellcheck disable=SC1091
    . "$OMA_REPO_DIR/scripts/lib/permissions.sh"

    env="${OMA_PERMISSIONS_ENV:-}"
    if [ -z "$env" ]; then
        project_dir="${OMA_PROJECT_DIR:-$PWD}"
        profile="$project_dir/.omao/profile.yaml"
        if [ -f "$profile" ]; then
            if command -v yq >/dev/null 2>&1; then
                env="$(yq -r '.aws.environment // ""' "$profile")"
            elif command -v python3 >/dev/null 2>&1; then
                env="$(python3 -c "import sys, yaml; d=yaml.safe_load(open(sys.argv[1])); print(d.get('aws',{}).get('environment',''))" "$profile")"
            fi
        fi
    fi

    if [ -z "$env" ]; then
        log "permissions: no .omao/profile.yaml aws.environment found; skipping (run 'oma setup' first)"
        return 0
    fi

    case "$env" in
        sandbox|staging|prod) ;;
        *) warn "permissions: unsupported env '$env'; skipping"; return 0 ;;
    esac

    PERMISSIONS_ENV="$env"
    resolved="$(perms_resolve_with_overlays "$env" "${OMA_PROJECT_DIR:-$PWD}")"
    autoapprove="$(printf '%s' "$resolved" | perms_to_kiro_autoapprove)"
    deny_bash="$(printf  '%s' "$resolved" | jq '.deny.bash  // []')"
    deny_edit="$(printf  '%s' "$resolved" | jq '.deny.edit  // []')"
    deny_write="$(printf '%s' "$resolved" | jq '.deny.write // []')"
    deny_mcp="$(printf   '%s' "$resolved" | jq '.deny.mcp   // []')"

    log "permissions: applying template chain for env=$env"
    perms_print_summary "$resolved" >&2
    if [ "$(printf '%s' "$resolved" | jq -r '._meta.overlay_applied // false')" = "true" ]; then
        log "permissions: overlay $(printf '%s' "$resolved" | jq -r '._meta.overlay_path') applied"
    fi

    # 1) cli.json — global autoApprove. Other keys (defaultModel, steering, …)
    #    preserved. Existing autoApprove keys win where the template did not
    #    set them; template wins where it did (it is the security floor).
    cli_json="$KIRO_HOME/settings/cli.json"
    if [ -f "$cli_json" ]; then
        tmp="$(mktemp)"
        if jq --argjson a "$autoapprove" '.autoApprove = ((.autoApprove // {}) + $a)' "$cli_json" > "$tmp"; then
            mv "$tmp" "$cli_json"
            log "permissions: patched $cli_json autoApprove"
            PERMISSIONS_APPLIED=$((PERMISSIONS_APPLIED + 1))
        else
            warn "permissions: failed to patch $cli_json (left untouched)"
            rm -f "$tmp"
        fi
    else
        log "permissions: $cli_json not present yet (run install_settings first); skipping cli.json"
    fi

    # 2) agents/*.agent.json — patch the user-side copies under
    #    ~/.kiro/agents/, never the source repo files. install_agents has
    #    already symlinked the source files into KIRO_HOME/agents/. We
    #    materialize each OMA-owned symlink as a real copy on first run
    #    so we never mutate the tracked repo files (and `git status`
    #    stays clean).
    agents_target="$KIRO_HOME/agents"
    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        plugin_agents="$OMA_REPO_DIR/plugins/$plugin/kiro-agents"
        [ -d "$plugin_agents" ] || continue
        for src_agent in "$plugin_agents"/*.json; do
            [ -f "$src_agent" ] || continue
            agent_name="$(basename "$src_agent")"
            dst="$agents_target/$agent_name"

            # Always materialize from the source repo: drop any existing
            # symlink, then write a patched real-file copy. This keeps user
            # copies in sync with upstream agent.json updates while never
            # mutating the tracked repo files. Refuse to overwrite a
            # non-symlink, non-OMA-meta file so we never trample a user
            # who hand-edited an agent profile.
            if [ -e "$dst" ] && [ ! -L "$dst" ]; then
                if ! jq -e '._meta.oma_permissions_env' "$dst" >/dev/null 2>&1; then
                    warn "permissions: refusing to overwrite hand-edited $dst (delete it to re-apply)"
                    continue
                fi
            fi

            ensure_dir "$agents_target"
            tmp="$(mktemp)"
            if jq \
                --argjson a   "$autoapprove" \
                --argjson db  "$deny_bash"   \
                --argjson de  "$deny_edit"   \
                --argjson dw  "$deny_write"  \
                --argjson dm  "$deny_mcp"    \
                --arg     env "$env"         '
                .autoApprove = ((.autoApprove // {}) + $a)
                | ._meta //= {}
                | ._meta.oma_permissions_env = $env
                | ._meta.oma_permissions_deny = {
                    bash:  $db,
                    edit:  $de,
                    write: $dw,
                    mcp:   $dm
                  }
                ' "$src_agent" > "$tmp"; then
                # Replace whatever currently lives at $dst (symlink or
                # OMA-meta-tagged file) with the freshly patched copy.
                if [ -e "$dst" ] || [ -L "$dst" ]; then
                    rm -f "$dst"
                fi
                mv "$tmp" "$dst"
                log "permissions: wrote ${dst#"$KIRO_HOME"/}"
                PERMISSIONS_APPLIED=$((PERMISSIONS_APPLIED + 1))
            else
                warn "permissions: failed to render $src_agent → $dst (left untouched)"
                rm -f "$tmp"
            fi
        done
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

summary() {
    cat <<EOF

Installation complete.
    skills linked         : $SKILLS_LINKED
    kiro.meta.yaml found  : $KIRO_META_FOUND
    guides linked         : $GUIDES_LINKED
    agents linked         : $AGENTS_LINKED
    settings installed    : $SETTINGS_INSTALLED
    permissions applied   : $PERMISSIONS_APPLIED files${PERMISSIONS_ENV:+ (env=$PERMISSIONS_ENV)}
EOF
    if [ "$KIRO_META_FOUND" -gt 0 ]; then
        cat <<'NOTE'

Note: kiro.meta.yaml sidecars contain Kiro-specific trigger and context hints.
Kiro will load them automatically alongside each SKILL.md.
NOTE
    fi
    if [ "$GUIDES_LINKED" -gt 0 ]; then
        cat <<'NOTE'

Note: guides/ directories contain stage-gated safety-critical content loaded per-stage.
Kiro will load them based on workflow context.
NOTE
    fi
    if [ "$AGENTS_LINKED" -gt 0 ]; then
        cat <<'NOTE'

Note: Kiro agent configurations include MCP server configs and auto-approval rules.
Use these agent profiles for specialized workflows.
NOTE
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            --skip-permissions) SKIP_PERMISSIONS=1; shift ;;
            *) die "unknown argument: $1 (try --help)" ;;
        esac
    done
    require jq
    log "OMA repo : $OMA_REPO_DIR"
    log "KIRO_HOME: $KIRO_HOME"
    log "OMA_OWNER: $OMA_OWNER"
    install_skills
    install_steering
    install_guides
    install_agents
    install_settings
    install_permissions
    summary
}

main "$@"
