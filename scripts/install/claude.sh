#!/usr/bin/env bash
# install-claude.sh
# Installs oh-my-aidlcops (OMA) plugins into the current user's ~/.claude/ directory.
# POSIX-compatible bash; idempotent; safe to re-run.
#
# Symlinks each plugin under .claude/plugins/<name>/, wires the /oma:* command
# tree, merges each plugin's .mcp.json into .claude/settings.json, and registers
# the OMA UserPromptSubmit / SessionStart hooks.

set -euo pipefail
# IFS kept at default; local `IFS=` is set per `read` loop below.

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
OMA_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OMA_OWNER="${OMA_OWNER:-aws-samples}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MARKETPLACE_JSON="$OMA_REPO_DIR/.claude-plugin/marketplace.json"
HOOKS_DIR="$OMA_REPO_DIR/hooks"
STEERING_CMDS_DIR="$OMA_REPO_DIR/steering/commands/oma"

PLUGINS_INSTALLED=0
MCP_SERVERS_MERGED=0
HOOKS_REGISTERED=0

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
install-claude.sh — Install oh-my-aidlcops (OMA) into ~/.claude/

Usage:
    bash scripts/install-claude.sh [--help] [--dry-run]

Environment:
    OMA_OWNER      GitHub owner for the marketplace (default: aws-samples).
    CLAUDE_HOME    Target Claude directory (default: $HOME/.claude).

What it does:
    1. Create ~/.claude/plugins/<plugin>/ symlinks for every plugin listed in
       .claude-plugin/marketplace.json.
    2. Symlink steering/commands/oma/ -> ~/.claude/commands/oma/ so /oma:*
       slash commands resolve.
    3. Merge each plugin's .mcp.json mcpServers map into ~/.claude/settings.json
       non-destructively via jq.
    4. Register the OMA UserPromptSubmit and SessionStart hook scripts.

Dependencies: jq, bash 4+.
The script is idempotent — re-running will refresh symlinks and re-merge only
entries that are missing.
EOF
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '[install-claude] %s\n' "$*"; }
warn() { printf '[install-claude][warn] %s\n' "$*" >&2; }
die()  { printf '[install-claude][error] %s\n' "$*" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 (install it and re-run)"
}

ensure_dir() {
    [ -d "$1" ] || mkdir -p "$1"
}

# Create or refresh a symlink. Removes an existing symlink pointing to a
# stale target; refuses to touch a real file/dir so we never destroy user data.
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

# Merge two JSON objects/files via jq. Writes result atomically. Accepts empty
# destination path — creates it with `{}` first when needed.
# Usage: merge_json_object <dest-file> <additions-file> <jq-merge-expr>
merge_json_object() {
    dest="$1"; add="$2"; expr="$3"
    ensure_dir "$(dirname "$dest")"
    [ -f "$dest" ] || printf '{}\n' > "$dest"
    [ -s "$dest" ] || printf '{}\n' > "$dest"
    tmp="$(mktemp)"
    jq --slurpfile add "$add" "$expr" "$dest" > "$tmp"
    mv "$tmp" "$dest"
}

# ---------------------------------------------------------------------------
# Install phases
# ---------------------------------------------------------------------------
install_plugins() {
    log "scanning marketplace: $MARKETPLACE_JSON"
    [ -f "$MARKETPLACE_JSON" ] || die "marketplace.json not found at $MARKETPLACE_JSON"

    plugins_target="$CLAUDE_HOME/plugins"
    ensure_dir "$plugins_target"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        src="$OMA_REPO_DIR/plugins/$plugin"
        dst="$plugins_target/$plugin"
        if [ ! -d "$src" ]; then
            warn "plugin directory missing, skipping: $src"
            continue
        fi
        if link_or_refresh "$src" "$dst"; then
            log "plugin linked: $plugin"
            PLUGINS_INSTALLED=$((PLUGINS_INSTALLED + 1))
        fi
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

install_commands() {
    if [ ! -d "$STEERING_CMDS_DIR" ]; then
        warn "no steering/commands/oma/ directory (skipping slash-command link)"
        return 0
    fi
    dst="$CLAUDE_HOME/commands/oma"
    if link_or_refresh "$STEERING_CMDS_DIR" "$dst"; then
        log "commands linked: $dst"
    fi
}

# Merge plugin-level .mcp.json files into ~/.claude/settings.json under the
# top-level mcpServers key (Claude Code native location).
install_mcp_servers() {
    settings="$CLAUDE_HOME/settings.json"
    ensure_dir "$(dirname "$settings")"
    [ -f "$settings" ] || printf '{}\n' > "$settings"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        mcp_file="$OMA_REPO_DIR/plugins/$plugin/.mcp.json"
        [ -f "$mcp_file" ] || continue
        # Merge the plugin's mcpServers object into the root settings.json.
        # Existing entries are preserved; only missing keys are added.
        added_count=$(jq -r --slurpfile add "$mcp_file" '
            ($add[0].mcpServers // {}) as $new
            | (.mcpServers // {}) as $cur
            | [$new | keys[] | select(in($cur) | not)] | length
        ' "$settings")
        merge_json_object "$settings" "$mcp_file" '
            (.mcpServers //= {})
            | .mcpServers = (($add[0].mcpServers // {}) + .mcpServers)
        '
        MCP_SERVERS_MERGED=$((MCP_SERVERS_MERGED + added_count))
        log "mcp merged: $plugin (+$added_count new servers)"
    done < <(jq -r '.plugins[].name' "$MARKETPLACE_JSON")
}

# Register UserPromptSubmit + SessionStart hooks pointing to OMA repo scripts.
install_hooks() {
    settings="$CLAUDE_HOME/settings.json"
    [ -f "$settings" ] || printf '{}\n' > "$settings"

    for pair in "UserPromptSubmit:user-prompt-submit.sh" "SessionStart:session-start.sh"; do
        event="${pair%%:*}"
        script_name="${pair##*:}"
        script_path="$HOOKS_DIR/$script_name"
        if [ ! -f "$script_path" ]; then
            log "hook script absent, skipping: $script_path"
            continue
        fi
        tmp="$(mktemp)"
        jq --arg event "$event" --arg cmd "$script_path" '
            .hooks //= {}
            | .hooks[$event] //= []
            | if any(.hooks[$event][]?.hooks[]?; .command == $cmd) then
                  .
              else
                  .hooks[$event] += [{
                      "matcher": "",
                      "hooks": [{"type": "command", "command": $cmd}]
                  }]
              end
        ' "$settings" > "$tmp"
        mv "$tmp" "$settings"
        HOOKS_REGISTERED=$((HOOKS_REGISTERED + 1))
        log "hook registered: $event -> $script_path"
    done
}

summary() {
    cat <<EOF

Installation complete.
    plugins installed : $PLUGINS_INSTALLED
    MCP servers added : $MCP_SERVERS_MERGED
    hooks registered  : $HOOKS_REGISTERED

Next steps:
    - Start Claude Code: \`claude\`
    - Verify plugins:    \`/plugin list\`
    - Verify commands:   type \`/oma:\` and look for suggestions.
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        --dry-run)
            log "dry-run mode not implemented; exiting without side effects"
            exit 0
            ;;
    esac
    require jq
    log "OMA repo  : $OMA_REPO_DIR"
    log "CLAUDE_HOME: $CLAUDE_HOME"
    log "OMA_OWNER : $OMA_OWNER"
    install_plugins
    install_commands
    install_mcp_servers
    install_hooks
    summary
}

main "$@"
