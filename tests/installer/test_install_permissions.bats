#!/usr/bin/env bats
# tests/installer/test_install_permissions.bats
# End-to-end coverage for install_permissions() in scripts/install/{claude,kiro}.sh.
# Each test runs the real install script against an isolated CLAUDE_HOME /
# KIRO_HOME and a mocked .omao/profile.yaml so nothing in the user's actual
# config is touched.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CLAUDE_INSTALL="$REPO_ROOT/scripts/install/claude.sh"
    KIRO_INSTALL="$REPO_ROOT/scripts/install/kiro.sh"
    SANDBOX_DIR="$(mktemp -d)"
    PROJECT="$SANDBOX_DIR/proj"
    mkdir -p "$PROJECT/.omao"
    export CLAUDE_HOME="$SANDBOX_DIR/claude"
    export KIRO_HOME="$SANDBOX_DIR/kiro"
    export OMA_PROJECT_DIR="$PROJECT"
    export NO_COLOR=1 OMA_QUIET=1
}

teardown() {
    rm -rf "$SANDBOX_DIR"
}

# Helper: write a minimal profile.yaml with the requested aws.environment.
write_profile() {
    env="$1"
    cat > "$PROJECT/.omao/profile.yaml" <<YAML
version: 1
created_at: "2026-05-09T00:00:00Z"
harness: { primary: claude-code, secondary: null }
aws:
  account_id: "123456789012"
  region: ap-northeast-2
  profile_name: default
  environment: $env
aidlc: { entry_phase: inception, strict_gates: false }
approval: { mode: interactive, blast_radius_ceiling: single-account }
budgets: { default_monthly_usd: 200, warn_at_pct: 80, block_at_pct: 100 }
observability: { mode: langfuse-managed, endpoint: null }
YAML
}

# ---------------- Claude ----------------

@test "claude.sh sandbox emits a non-empty permissions.deny" {
    write_profile sandbox
    run bash "$CLAUDE_INSTALL"
    [ "$status" -eq 0 ]
    settings="$CLAUDE_HOME/settings.json"
    [ -f "$settings" ]
    count=$(jq '.permissions.deny | length' "$settings")
    [ "$count" -gt 0 ]
}

@test "claude.sh prod deny is strictly larger than sandbox deny" {
    write_profile sandbox
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    sandbox_count=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")

    rm -rf "$CLAUDE_HOME"
    write_profile prod
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    prod_count=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")

    [ "$prod_count" -gt "$sandbox_count" ] || {
        echo "expected prod ($prod_count) > sandbox ($sandbox_count)"
        return 1
    }
}

@test "claude.sh second run is idempotent (no duplicate deny entries)" {
    write_profile prod
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    first=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    second=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")
    [ "$first" -eq "$second" ]
}

@test "claude.sh stamps the OMA permissions sentinel after a successful install" {
    write_profile sandbox
    # Capture status + output so that a silent install_permissions early-return
    # (e.g. PyYAML missing on the python3 the test inherits) surfaces here
    # instead of bubbling up as a confusing `[ -f sentinel ]` failure two
    # lines later.
    run bash "$CLAUDE_INSTALL"
    [ "$status" -eq 0 ] || {
        echo "claude install exit=$status; output below:" >&2
        echo "$output" >&2
        return 1
    }
    [ -f "$CLAUDE_HOME/.oma-permissions-applied-at" ] || {
        echo "sentinel missing — install output:" >&2
        echo "$output" >&2
        return 1
    }
    # Sentinel mtime should not be older than the overlay file we'd compare it against.
    # GNU stat (Linux/CI) first, BSD stat (macOS) as the fallback. The previous
    # order tried `stat -f %m` first; on GNU stat that reads %m as a filename,
    # exits non-zero BUT still prints filesystem info to stdout, so the captured
    # value became multi-line garbage and `-gt 0` died with status 2.
    sentinel_mtime=$(stat -c %Y "$CLAUDE_HOME/.oma-permissions-applied-at" 2>/dev/null || stat -f %m "$CLAUDE_HOME/.oma-permissions-applied-at" 2>/dev/null)
    [ "$sentinel_mtime" -gt 0 ]
}

@test "kiro.sh stamps the OMA permissions sentinel after a successful install" {
    write_profile prod
    run bash "$KIRO_INSTALL"
    [ "$status" -eq 0 ] || {
        echo "kiro install exit=$status; output below:" >&2
        echo "$output" >&2
        return 1
    }
    [ -f "$KIRO_HOME/.oma-permissions-applied-at" ]
}

@test "claude.sh preserves user-authored permissions.deny entries" {
    write_profile sandbox
    mkdir -p "$CLAUDE_HOME"
    cat > "$CLAUDE_HOME/settings.json" <<'JSON'
{
  "permissions": {
    "deny": ["Bash(rm -rf /)", "Edit(/Users/me/secret.txt)"]
  }
}
JSON
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    # User's entries survive verbatim.
    jq -e '.permissions.deny | index("Bash(rm -rf /)") != null' "$CLAUDE_HOME/settings.json"
    jq -e '.permissions.deny | index("Edit(/Users/me/secret.txt)") != null' "$CLAUDE_HOME/settings.json"
}

@test "claude.sh --skip-permissions leaves permissions key absent" {
    write_profile prod
    run bash "$CLAUDE_INSTALL" --skip-permissions
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_HOME/settings.json" ]
    # No permissions.deny added by us.
    jq -e '.permissions == null or (.permissions.deny // [] | length == 0)' "$CLAUDE_HOME/settings.json"
}

@test "claude.sh OMA_PERMISSIONS_ENV overrides profile.yaml" {
    write_profile sandbox
    OMA_PERMISSIONS_ENV=prod bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    overridden=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")

    rm -rf "$CLAUDE_HOME"
    write_profile sandbox
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    natural=$(jq '.permissions.deny | length' "$CLAUDE_HOME/settings.json")

    [ "$overridden" -gt "$natural" ]
}

@test "claude.sh skips gracefully when profile.yaml is absent" {
    rm -f "$PROJECT/.omao/profile.yaml"
    run bash "$CLAUDE_INSTALL"
    [ "$status" -eq 0 ]
    # settings.json may exist (other steps run) but no permissions tree.
    if [ -f "$CLAUDE_HOME/settings.json" ]; then
        jq -e '.permissions == null or (.permissions.deny // [] | length == 0)' "$CLAUDE_HOME/settings.json"
    fi
}

# ---------------- Kiro ----------------

@test "kiro.sh prod tags agent.json with _meta.oma_permissions_env" {
    write_profile prod
    run bash "$KIRO_INSTALL"
    [ "$status" -eq 0 ]
    agent="$KIRO_HOME/agents/ai-infra.agent.json"
    [ -f "$agent" ]
    jq -e '._meta.oma_permissions_env == "prod"' "$agent"
    jq -e '._meta.oma_permissions_deny.bash | length > 0' "$agent"
}

@test "kiro.sh sandbox keeps autoApprove.fileWrites=true" {
    write_profile sandbox
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    jq -e '.autoApprove.fileWrites == true' "$KIRO_HOME/settings/cli.json"
    jq -e '.autoApprove.fileWrites == true' "$KIRO_HOME/agents/ai-infra.agent.json"
}

@test "kiro.sh prod tightens autoApprove.bashCommands to false" {
    write_profile prod
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    jq -e '.autoApprove.bashCommands == false' "$KIRO_HOME/settings/cli.json"
    jq -e '.autoApprove.bashCommands == false' "$KIRO_HOME/agents/ai-infra.agent.json"
}

@test "kiro.sh leaves source repo agent files unmodified" {
    src="$REPO_ROOT/plugins/ai-infra/kiro-agents/ai-infra.agent.json"
    before=$(shasum -a 256 "$src" | awk '{print $1}')
    write_profile prod
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    after=$(shasum -a 256 "$src" | awk '{print $1}')
    [ "$before" = "$after" ]
}

@test "kiro.sh refuses to overwrite a hand-edited agent.json" {
    write_profile prod
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    agent="$KIRO_HOME/agents/ai-infra.agent.json"
    # Strip OMA's audit tag — simulates a user who hand-edited the file.
    tmp=$(mktemp)
    jq 'del(._meta.oma_permissions_env)' "$agent" > "$tmp"
    mv "$tmp" "$agent"
    # Mark a sentinel field the install must not overwrite.
    tmp=$(mktemp)
    jq '.welcomeMessage = "USER_EDIT_SENTINEL"' "$agent" > "$tmp"
    mv "$tmp" "$agent"

    run bash "$KIRO_INSTALL"
    [ "$status" -eq 0 ]
    # Sentinel survives.
    jq -e '.welcomeMessage == "USER_EDIT_SENTINEL"' "$agent"
}

@test "kiro.sh second run picks up upstream agent.json changes" {
    write_profile prod
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    agent="$KIRO_HOME/agents/ai-infra.agent.json"
    src="$REPO_ROOT/plugins/ai-infra/kiro-agents/ai-infra.agent.json"
    # Sanity — the OMA-tagged copy reflects the source description.
    src_desc=$(jq -r '.description' "$src")
    user_desc=$(jq -r '.description' "$agent")
    [ "$src_desc" = "$user_desc" ]
}

@test "kiro.sh --skip-permissions does not write _meta.oma_permissions_env" {
    write_profile prod
    run bash "$KIRO_INSTALL" --skip-permissions
    [ "$status" -eq 0 ]
    agent="$KIRO_HOME/agents/ai-infra.agent.json"
    # Either no agent yet or no _meta tag — both acceptable.
    if [ -e "$agent" ]; then
        # _meta may carry pre-existing keys (e.g. eks_mcp_flags). We only
        # care that install_permissions did not stamp its env tag.
        jq -e '._meta.oma_permissions_env == null' "$agent" || {
            jq '._meta' "$agent"
            return 1
        }
    fi
}
