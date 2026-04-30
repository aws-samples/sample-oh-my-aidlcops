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
    echo "$output" | jq -e '.additionalContext | contains("[OMA Ontology]")' >/dev/null
    echo "$output" | jq -e '.additionalContext | contains("Budget default-monthly")' >/dev/null
}

@test "session-start includes open incident" {
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.additionalContext | contains("Incident inc-test-001")' >/dev/null
}

@test "session-start includes proposed deployment" {
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.additionalContext | contains("Deployment vllm-mini")' >/dev/null
}

@test "OMA_DISABLE_ONTOLOGY skips ontology block" {
    cd "$PROJECT"
    OMA_DISABLE_ONTOLOGY=1 run bash "$HOOK"
    [ "$status" -eq 0 ]
    run jq -e '.additionalContext | contains("[OMA Ontology]") | not' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "no ontology directory: hook still succeeds" {
    rm -rf "$PROJECT/.omao/ontology"
    cd "$PROJECT"
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.additionalContext' >/dev/null
}
