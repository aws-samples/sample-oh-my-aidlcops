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

@test "child template can override parent auto_approve true to false" {
    # Regression for the jq `//` falsy collapse: if the merge uses
    # `(child.k // parent.k)`, a child setting `false` against a parent set
    # to `true` produces `true` (jq treats `false` as a null alternative).
    # The fix uses explicit `has(k)` so the child's literal `false` is
    # honored.
    tmpl_dir="$(mktemp -d)"
    cat > "$tmpl_dir/common.yaml" <<'EOF'
version: 1
deny: { bash: [], edit: [], write: [], mcp: [] }
auto_approve: { read_only: true, file_writes: true, bash_commands: true }
EOF
    cat > "$tmpl_dir/sandbox.yaml" <<'EOF'
version: 1
extends: ["common.yaml"]
deny: { bash: [], edit: [], write: [], mcp: [] }
auto_approve: { read_only: true, file_writes: false, bash_commands: false }
EOF

    out=$(bash -c "
        . '$LIB'
        perms_template_dir() { printf '%s' '$tmpl_dir'; }
        perms_resolve sandbox | jq -c '.auto_approve'
    ")
    rm -rf "$tmpl_dir"

    [ "$out" = '{"read_only":true,"file_writes":false,"bash_commands":false}' ] || {
        echo "got: $out"
        return 1
    }
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

@test "overlay deny.add appends to the resolved set" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    cat > "$proj/.omao/permissions.yaml" <<'EOF'
version: 1
deny:
  add:
    edit: ["infra/secrets/**"]
EOF
    has=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq '.deny.edit | any(test(\"infra/secrets\"))'")
    rm -rf "$proj"
    [ "$has" = "true" ]
}

@test "overlay deny.remove subtracts from the resolved set" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    # Pick an entry that's actually in prod.
    target="kubectl delete ns*"
    cat > "$proj/.omao/permissions.yaml" <<EOF
version: 1
deny:
  remove:
    bash: ["$target"]
EOF
    base_count=$(bash -c ". '$LIB' && perms_resolve prod | jq '.deny.bash | length'")
    overlay_count=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq '.deny.bash | length'")
    rm -rf "$proj"
    [ "$overlay_count" -eq $((base_count - 1)) ]
}

@test "overlay auto_approve.bash_commands=true overrides prod default false" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    cat > "$proj/.omao/permissions.yaml" <<'EOF'
version: 1
auto_approve:
  bash_commands: true
EOF
    out=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq -r '.auto_approve.bash_commands'")
    rm -rf "$proj"
    [ "$out" = "true" ]
}

@test "absent overlay leaves base resolution unchanged" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    base=$(bash -c ". '$LIB' && perms_resolve prod | jq -c .")
    overlay=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq -c 'del(._meta.overlay_path, ._meta.overlay_applied)'")
    rm -rf "$proj"
    [ "$base" = "$overlay" ]
}

@test "overlay marks _meta.overlay_applied true when any rule fires" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    cat > "$proj/.omao/permissions.yaml" <<'EOF'
version: 1
deny:
  add:
    bash: ["echo overlay-only"]
EOF
    flag=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq -r '._meta.overlay_applied'")
    rm -rf "$proj"
    [ "$flag" = "true" ]
}

@test "overlay with empty schema does not set overlay_applied" {
    proj=$(mktemp -d)
    mkdir -p "$proj/.omao"
    cat > "$proj/.omao/permissions.yaml" <<'EOF'
version: 1
EOF
    flag=$(bash -c ". '$LIB' && perms_resolve_with_overlays prod '$proj' | jq -r '._meta.overlay_applied'")
    rm -rf "$proj"
    [ "$flag" = "false" ]
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
