#!/usr/bin/env bats
# tests/installer/test_permissions_lib.bats
# Unit tests for scripts/lib/permissions.sh — the shared resolver that turns
# templates/permissions/<env>.yaml into the JSON document both install
# scripts ingest. Verifies extends-merge semantics (arrays union+uniq+sort,
# scalars child-wins), env validation, and the Claude / Kiro emitters.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    LIB="$REPO_ROOT/scripts/lib/permissions.sh"
    export NO_COLOR=1 OMA_QUIET=1
}

# Source the lib in a subshell and run a small jq pipeline on the resolved
# document. Keeps each @test case to one assertion.
resolve_jq() {
    env="$1"; expr="$2"
    bash -c ". '$LIB' && perms_resolve '$env'" | jq -r "$expr"
}

@test "perms_resolve sandbox emits the documented schema shape" {
    json=$(bash -c ". '$LIB' && perms_resolve sandbox")
    echo "$json" | jq -e '
        has("auto_approve") and has("deny") and has("_meta")
        and (.auto_approve | type) == "object"
        and (.deny.bash  | type) == "array"
        and (.deny.edit  | type) == "array"
        and (.deny.write | type) == "array"
        and (.deny.mcp   | type) == "array"
    '
}

@test "perms_resolve rejects unknown env with non-zero status" {
    run bash -c ". '$LIB' && perms_resolve nope"
    [ "$status" -ne 0 ]
}

@test "perms_resolve <env> includes common.yaml in the templates chain" {
    run resolve_jq sandbox '._meta.templates | join(",")'
    [ "$status" -eq 0 ]
    [[ "$output" == "common.yaml,sandbox.yaml" ]]
}

@test "common audit-ledger guard is inherited by every env" {
    for env in sandbox staging prod; do
        run resolve_jq "$env" '.deny.bash | map(select(test("audit"))) | length > 0'
        [ "$status" -eq 0 ]
        [ "$output" = "true" ] || {
            echo "$env did not inherit the audit ledger guard"
            return 1
        }
    done
}

@test "deny arrays are unique and sorted" {
    json=$(bash -c ". '$LIB' && perms_resolve prod")
    echo "$json" | jq -e '
        (.deny.bash  == (.deny.bash  | unique | sort))
        and (.deny.edit  == (.deny.edit  | unique | sort))
        and (.deny.write == (.deny.write | unique | sort))
        and (.deny.mcp   == (.deny.mcp   | unique | sort))
    '
}

@test "sandbox auto-approves bash but prod does not" {
    run resolve_jq sandbox '.auto_approve.bash_commands'
    [ "$status" -eq 0 ]; [ "$output" = "true" ]
    run resolve_jq prod '.auto_approve.bash_commands'
    [ "$status" -eq 0 ]; [ "$output" = "false" ]
}

@test "auto_approve.read_only stays true across all envs" {
    for env in sandbox staging prod; do
        run resolve_jq "$env" '.auto_approve.read_only'
        [ "$status" -eq 0 ]
        [ "$output" = "true" ]
    done
}

@test "prod deny set is a strict superset of staging" {
    staging=$(bash -c ". '$LIB' && perms_resolve staging | jq -r '.deny.bash[]'")
    prod=$(bash    -c ". '$LIB' && perms_resolve prod    | jq -r '.deny.bash[]'")
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        echo "$prod" | grep -Fxq "$line" || {
            echo "staging deny entry missing from prod: $line"
            return 1
        }
    done <<< "$staging"
}

@test "perms_to_claude_deny wraps bash/edit/write and leaves mcp bare" {
    out=$(bash -c ". '$LIB' && perms_resolve prod | perms_to_claude_deny")
    # Bash entries
    echo "$out" | jq -e 'map(select(startswith("Bash("))) | length > 0'
    # Edit entries
    echo "$out" | jq -e 'map(select(startswith("Edit("))) | length > 0'
    # Write entries
    echo "$out" | jq -e 'map(select(startswith("Write("))) | length > 0'
    # MCP entries left bare (no wrapping prefix)
    echo "$out" | jq -e 'map(select(startswith("mcp__"))) | length > 0'
}

@test "perms_to_kiro_autoapprove emits Kiro key casing" {
    out=$(bash -c ". '$LIB' && perms_resolve sandbox | perms_to_kiro_autoapprove")
    echo "$out" | jq -e 'has("readOnly") and has("fileWrites") and has("bashCommands")'
}

@test "perms_print_summary lines stay under 100 chars" {
    out=$(bash -c ". '$LIB' && resolved=\$(perms_resolve prod); perms_print_summary \"\$resolved\"" 2>&1)
    while IFS= read -r line; do
        len=${#line}
        [ "$len" -lt 100 ] || {
            echo "summary line too long ($len chars): $line"
            return 1
        }
    done <<< "$out"
}

@test "perms_resolve_for_profile reads aws.environment from a profile file" {
    tmp_profile="$(mktemp)"
    cat > "$tmp_profile" <<'YAML'
version: 1
created_at: "2026-05-09T00:00:00Z"
harness: { primary: claude-code, secondary: null }
aws:
  account_id: "123456789012"
  region: ap-northeast-2
  environment: staging
aidlc: { entry_phase: inception }
approval: { mode: interactive }
budgets: { default_monthly_usd: 100, warn_at_pct: 80, block_at_pct: 100 }
observability: { mode: none }
YAML
    out=$(bash -c ". '$LIB' && perms_resolve_for_profile '$tmp_profile' | jq -r '._meta.env'")
    rm -f "$tmp_profile"
    [ "$out" = "staging" ]
}
