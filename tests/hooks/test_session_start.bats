#!/usr/bin/env bats
# tests/hooks/test_session_start.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/hooks/session-start.sh"
    PROJECT="$(mktemp -d)"
    mkdir -p "$PROJECT/.omao/ontology/budgets" "$PROJECT/.omao/ontology/deployments" "$PROJECT/.omao/ontology/incidents"
    cat > "$PROJECT/.omao/ontology/budgets/default.json" <<'JSON'
{
  "id": "default-monthly",
  "scope": "account",
  "scope_ref": "123456789012",
  "limit_usd": 200,
  "period": "monthly",
  "rule_expression": "spend_usd > limit_usd * 0.8",
  "action_on_breach": "notify"
}
JSON
    cat > "$PROJECT/.omao/ontology/deployments/example.json" <<'JSON'
{
  "id": "vllm-mini",
  "target": "eks",
  "artifact": "public.ecr.aws/nginx",
  "approval_state": "proposed",
  "blast_radius": "single-namespace"
}
JSON
    cat > "$PROJECT/.omao/ontology/incidents/test-incident.json" <<'JSON'
{
  "id": "inc-test-001",
  "severity": "sev-3",
  "alarm_source": "CloudWatch:Test",
  "approval_state": "proposed"
}
JSON
}

teardown() {
    rm -rf "$PROJECT"
}

@test "session-start emits budget line when seed budget exists" {
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("[OMA Ontology]")' >/dev/null
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("Budget default-monthly")' >/dev/null
}

@test "session-start includes open incident" {
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("Incident inc-test-001")' >/dev/null
}

@test "session-start includes proposed deployment" {
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("Deployment vllm-mini")' >/dev/null
}

@test "OMA_DISABLE_ONTOLOGY skips ontology block" {
    cd "$PROJECT"
    OMA_DISABLE_ONTOLOGY=1 run bash "$HOOK"
    [ "$status" -eq 0 ]
    run jq -e '.hookSpecificOutput.additionalContext | contains("[OMA Ontology]") | not' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "no ontology directory: hook still succeeds" {
    rm -rf "$PROJECT/.omao/ontology"
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

@test "session-start emits OMA_PERMISSIONS_DRIFT when overlay newer than sentinel" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
deny:
  add:
    bash: ["test-pattern"]
YAML
    fake_home=$(mktemp -d)
    mkdir -p "$fake_home/.claude"
    : > "$fake_home/.claude/.oma-permissions-applied-at"
    # Backdate the OMA sentinel so the overlay is "newer".
    touch -t 202401010000 "$fake_home/.claude/.oma-permissions-applied-at"

    cd "$PROJECT"
    HOME="$fake_home" run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.additionalContext | contains("OMA_PERMISSIONS_DRIFT")'
    echo "$output" | jq -e '.additionalContext | contains("oma setup --skip-doctor")'
    rm -rf "$fake_home"
}

@test "no drift line when sentinel is newer than overlay" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    touch -t 202401010000 "$PROJECT/.omao/permissions.yaml"
    fake_home=$(mktemp -d)
    mkdir -p "$fake_home/.claude"
    : > "$fake_home/.claude/.oma-permissions-applied-at"   # current mtime, newer

    cd "$PROJECT"
    HOME="$fake_home" run bash "$HOOK"
    [ "$status" -eq 0 ]
    run jq -e '.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
    [ "$status" -eq 0 ]
    rm -rf "$fake_home"
}

@test "OMA_DISABLE_PERMISSIONS_DRIFT suppresses the drift line" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    fake_home=$(mktemp -d)
    mkdir -p "$fake_home/.claude"
    : > "$fake_home/.claude/.oma-permissions-applied-at"
    touch -t 202401010000 "$fake_home/.claude/.oma-permissions-applied-at"

    cd "$PROJECT"
    HOME="$fake_home" OMA_DISABLE_PERMISSIONS_DRIFT=1 run bash "$HOOK"
    [ "$status" -eq 0 ]
    run jq -e '.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
    [ "$status" -eq 0 ]
    rm -rf "$fake_home"
}

@test "no sentinel: drift detection silently skips (never installed)" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    fake_home=$(mktemp -d)   # no sentinel — install never ran
    cd "$PROJECT"
    HOME="$fake_home" run bash "$HOOK"
    [ "$status" -eq 0 ]
    run jq -e '.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
    [ "$status" -eq 0 ]
    rm -rf "$fake_home"
}

@test "kiro sentinel absent: only claude drift surfaces" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    fake_home=$(mktemp -d)
    # Only Claude sentinel exists, with stale mtime → claude drift expected.
    # No Kiro sentinel → must NOT mention kiro path.
    mkdir -p "$fake_home/.claude"
    : > "$fake_home/.claude/.oma-permissions-applied-at"
    touch -t 202401010000 "$fake_home/.claude/.oma-permissions-applied-at"

    cd "$PROJECT"
    HOME="$fake_home" run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.additionalContext | contains("OMA_PERMISSIONS_DRIFT")'
    # Drift body must NOT reference the kiro sentinel path.
    run jq -e '.additionalContext | contains(".kiro/.oma-permissions-applied-at") | not' <<<"$output"
    [ "$status" -eq 0 ]
    rm -rf "$fake_home"
}
