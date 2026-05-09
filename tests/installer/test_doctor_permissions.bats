#!/usr/bin/env bats
# tests/installer/test_doctor_permissions.bats
# Coverage for the `permissions-applied` probe in scripts/oma/doctor.sh.
#
# The probe runs against ~/.claude/settings.json and ~/.kiro/agents/. Every
# test below points HOME at a scratch directory and uses a mocked profile so
# we never touch the user's real install.
#
# We exercise the probe function directly (sourced into a probe harness) so
# the test suite stays robust against unrelated baseline failures elsewhere
# in doctor.sh (e.g. profile_validate dep handling).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    DOCTOR="$REPO_ROOT/scripts/oma/doctor.sh"
    CLAUDE_INSTALL="$REPO_ROOT/scripts/install/claude.sh"
    KIRO_INSTALL="$REPO_ROOT/scripts/install/kiro.sh"
    SANDBOX_DIR="$(mktemp -d)"
    PROJECT="$SANDBOX_DIR/proj"
    mkdir -p "$PROJECT/.omao"
    export HOME="$SANDBOX_DIR/home"
    export CLAUDE_HOME="$HOME/.claude"
    export KIRO_HOME="$HOME/.kiro"
    export OMA_PROJECT_DIR="$PROJECT"
    mkdir -p "$HOME"
    export NO_COLOR=1 OMA_QUIET=1
}

teardown() {
    rm -rf "$SANDBOX_DIR"
}

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

# Run probe_permissions_applied in isolation. Captures the last probe entry
# as $STATUS / $MESSAGE / $REMEDIATION for assertions.
run_probe() {
    bash -c '
        set +e
        REPO_ROOT="'"$REPO_ROOT"'"
        PROJECT_DIR="'"$PROJECT"'"
        . "$REPO_ROOT/scripts/lib/log.sh"
        PROBE_IDS=(); PROBE_LABELS=(); PROBE_STATUSES=(); PROBE_MESSAGES=(); PROBE_REMEDIATIONS=()
        record() {
            PROBE_IDS+=("$1"); PROBE_LABELS+=("$2"); PROBE_STATUSES+=("$3")
            PROBE_MESSAGES+=("$4"); PROBE_REMEDIATIONS+=("${5:-}")
        }
        eval "$(awk "/^probe_permissions_applied\\(\\)/,/^}$/" "$REPO_ROOT/scripts/oma/doctor.sh")"
        probe_permissions_applied
        printf "STATUS=%s\nMESSAGE=%s\nREMEDIATION=%s\n" \
            "${PROBE_STATUSES[-1]}" "${PROBE_MESSAGES[-1]}" "${PROBE_REMEDIATIONS[-1]}"
    '
}

@test "permissions-applied skips when no profile.yaml exists" {
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=skip$'
    echo "$out" | grep -q 'no profile yet'
}

@test "permissions-applied skips when neither harness is installed" {
    write_profile sandbox
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=skip$'
    echo "$out" | grep -q 'no Claude or Kiro install detected'
}

@test "permissions-applied passes after a clean Claude install" {
    write_profile sandbox
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=pass$'
    echo "$out" | grep -q 'env=sandbox'
    echo "$out" | grep -q 'claude'
}

@test "permissions-applied passes after a clean Kiro install" {
    write_profile prod
    bash "$KIRO_INSTALL" >/dev/null 2>&1
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=pass$'
    echo "$out" | grep -q 'env=prod'
    echo "$out" | grep -q 'kiro'
}

@test "permissions-applied warns when Claude deny list is truncated" {
    write_profile sandbox
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    # Drop everything except the first deny entry.
    tmp=$(mktemp)
    jq '.permissions.deny = [.permissions.deny[0]]' "$CLAUDE_HOME/settings.json" > "$tmp"
    mv "$tmp" "$CLAUDE_HOME/settings.json"

    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=warn$'
    echo "$out" | grep -q 'claude: [0-9]\+ missing deny entries'
    echo "$out" | grep -q 'REMEDIATION=Re-run'
}

@test "permissions-applied warns when profile env diverges from installed Kiro tag" {
    write_profile sandbox
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    bash "$KIRO_INSTALL"   >/dev/null 2>&1
    # Switch the profile to prod without re-running install — the agent.json
    # _meta tag still says sandbox.
    sed -i.bak 's/environment: sandbox/environment: prod/' "$PROJECT/.omao/profile.yaml"
    rm -f "$PROJECT/.omao/profile.yaml.bak"

    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=warn$'
    echo "$out" | grep -q 'env=prod'
    echo "$out" | grep -q 'kiro: 1 env-mismatch'
}

@test "permissions-applied warns when profile.yaml lacks aws.environment" {
    cat > "$PROJECT/.omao/profile.yaml" <<'YAML'
version: 1
created_at: "2026-05-09T00:00:00Z"
harness: { primary: claude-code, secondary: null }
aws: { account_id: "123456789012", region: ap-northeast-2, profile_name: default }
aidlc: { entry_phase: inception }
approval: { mode: interactive }
budgets: { default_monthly_usd: 200, warn_at_pct: 80, block_at_pct: 100 }
observability: { mode: none, endpoint: null }
YAML
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=warn$'
    echo "$out" | grep -q 'missing aws.environment'
}

@test "permissions-applied warns on unsupported aws.environment" {
    write_profile staging        # write a valid profile first
    sed -i.bak 's/environment: staging/environment: nope/' "$PROJECT/.omao/profile.yaml"
    rm -f "$PROJECT/.omao/profile.yaml.bak"

    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=warn$'
    echo "$out" | grep -q 'unsupported aws.environment: nope'
}

@test "permissions-applied passes after both Claude and Kiro installs" {
    write_profile prod
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    bash "$KIRO_INSTALL"   >/dev/null 2>&1
    out=$(run_probe)
    echo "$out" | grep -q '^STATUS=pass$'
    echo "$out" | grep -q 'env=prod'
    echo "$out" | grep -q 'claude'
    echo "$out" | grep -q 'kiro'
}
