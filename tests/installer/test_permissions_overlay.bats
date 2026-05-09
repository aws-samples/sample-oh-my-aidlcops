#!/usr/bin/env bats
# tests/installer/test_permissions_overlay.bats
# Coverage for the project-level overlay (.omao/permissions.yaml) end-to-end:
#   - `oma permissions show` / `path` subcommand
#   - install_permissions reflects the overlay
#   - doctor probe expects the overlay-resolved deny set

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    OMA_BIN="$REPO_ROOT/bin/oma"
    CLAUDE_INSTALL="$REPO_ROOT/scripts/install/claude.sh"
    SANDBOX_DIR="$(mktemp -d)"
    PROJECT="$SANDBOX_DIR/proj"
    mkdir -p "$PROJECT/.omao"
    export HOME="$SANDBOX_DIR/home"
    export CLAUDE_HOME="$HOME/.claude"
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
  environment: $env
aidlc: { entry_phase: inception }
approval: { mode: interactive }
budgets: { default_monthly_usd: 200, warn_at_pct: 80, block_at_pct: 100 }
observability: { mode: langfuse-managed, endpoint: null }
YAML
}

write_overlay() {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
deny:
  remove:
    bash: ["kubectl delete ns*"]
  add:
    edit: ["infra/secrets/**"]
auto_approve:
  bash_commands: true
YAML
}

# ---------------- oma permissions ----------------

@test "oma permissions path creates .omao/ and prints absolute path" {
    write_profile prod
    run "$OMA_BIN" permissions path --project "$PROJECT"
    [ "$status" -eq 0 ]
    [[ "$output" == "$PROJECT/.omao/permissions.yaml" ]]
    [ -d "$PROJECT/.omao" ]
}

@test "oma permissions show with no overlay reports (none)" {
    write_profile prod
    run "$OMA_BIN" permissions show --project "$PROJECT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"overlay : (none"* ]]
    [[ "$output" == *"templates : common.yaml + prod.yaml"* ]]
}

@test "oma permissions show with overlay tags entries by source" {
    write_profile prod
    write_overlay
    run "$OMA_BIN" permissions show --project "$PROJECT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"applied"* ]]
    [[ "$output" == *"[overlay"*"infra/secrets/**"* ]]
    [[ "$output" == *"overlay removals"* ]]
    [[ "$output" == *"kubectl delete ns*"* ]]
}

@test "oma permissions show --json carries overlay_applied flag" {
    write_profile prod
    write_overlay
    run "$OMA_BIN" permissions show --project "$PROJECT" --json
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.overlay_applied == true'
    echo "$output" | jq -e '.removed.bash | length == 1'
}

@test "oma permissions show fails on unknown env" {
    write_profile prod
    sed -i.bak 's/environment: prod/environment: nope/' "$PROJECT/.omao/profile.yaml"
    rm -f "$PROJECT/.omao/profile.yaml.bak"
    run "$OMA_BIN" permissions show --project "$PROJECT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported aws.environment"* ]]
}

# ---------------- install reflects overlay ----------------

@test "claude.sh install_permissions honors overlay deny.remove" {
    write_profile prod
    write_overlay
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    # Removed entry must NOT be in the live deny set.
    jq -e '.permissions.deny | any(. == "Bash(kubectl delete ns*)") | not' \
        "$CLAUDE_HOME/settings.json"
}

@test "claude.sh install_permissions honors overlay deny.add" {
    write_profile prod
    write_overlay
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1
    jq -e '.permissions.deny | any(. == "Edit(infra/secrets/**)")' \
        "$CLAUDE_HOME/settings.json"
}

# ---------------- doctor reflects overlay ----------------

@test "doctor probe passes when overlay is applied to the install" {
    write_profile prod
    write_overlay
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1

    # Source probe in isolation (skips unrelated baseline failures).
    out=$(bash -c '
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
        printf "STATUS=%s\nMESSAGE=%s\n" "${PROBE_STATUSES[-1]}" "${PROBE_MESSAGES[-1]}"
    ')
    echo "$out" | grep -q '^STATUS=pass$'
}

@test "doctor probe warns when overlay edited but install not re-run" {
    write_profile prod
    bash "$CLAUDE_INSTALL" >/dev/null 2>&1   # no overlay yet -> baseline applied
    write_overlay                            # add overlay AFTER install
    out=$(bash -c '
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
        printf "STATUS=%s\nMESSAGE=%s\n" "${PROBE_STATUSES[-1]}" "${PROBE_MESSAGES[-1]}"
    ')
    echo "$out" | grep -q '^STATUS=warn$'
    # The overlay added Edit(infra/secrets/**); probe should report it missing.
    echo "$out" | grep -q 'missing deny entries'
}
