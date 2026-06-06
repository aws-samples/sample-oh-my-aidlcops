#!/usr/bin/env bats
# tests/profile/test_setup_non_interactive.bats
# Drives `oma setup --non-interactive --skip-install --skip-doctor` end-to-end
# in a scratch project directory and asserts the resulting artefacts validate.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    OMA_BIN="$REPO_ROOT/bin/oma"
    PROJECT="$(mktemp -d)"
    export NO_COLOR=1 OMA_QUIET=1
}

teardown() {
    rm -rf "$PROJECT"
}

@test "setup --non-interactive creates a valid profile" {
    run env -i PATH="$PATH" HOME="$HOME" \
        OMA_NON_INTERACTIVE=1 \
        OMA_HARNESS=claude-code \
        OMA_AWS_ACCOUNT=123456789012 \
        OMA_AWS_REGION=ap-northeast-2 \
        OMA_AWS_ENV=sandbox \
        OMA_AIDLC_PHASE=inception \
        OMA_APPROVAL_MODE=interactive \
        OMA_BUDGET_USD=200 \
        OMA_OBSERVABILITY=langfuse-managed \
        bash -c "cd '$PROJECT' && '$OMA_BIN' setup --non-interactive --skip-install --skip-doctor"
    if [ "$status" -ne 0 ]; then
        echo "--- stdout/stderr ---"
        echo "$output"
    fi
    [ "$status" -eq 0 ]
    [ -f "$PROJECT/.omao/profile.yaml" ]
    [ -f "$PROJECT/.omao/ontology/budgets/default.json" ]
    [ -f "$PROJECT/.omao/ontology/deployments/example.json" ]
    [ -f "$PROJECT/.omao/ontology/risks/bootstrap.json" ]
    [ -f "$PROJECT/.omao/permissions.yaml" ]
}

@test "setup seeds permissions.yaml as a no-op overlay (all commented)" {
    run env -i PATH="$PATH" HOME="$HOME" \
        OMA_NON_INTERACTIVE=1 OMA_HARNESS=claude-code \
        OMA_AWS_ACCOUNT=123456789012 OMA_AWS_REGION=ap-northeast-2 \
        OMA_AWS_ENV=prod OMA_AIDLC_PHASE=inception \
        OMA_APPROVAL_MODE=interactive OMA_BUDGET_USD=200 \
        OMA_OBSERVABILITY=langfuse-managed \
        bash -c "cd '$PROJECT' && '$OMA_BIN' setup --non-interactive --skip-install --skip-doctor"
    [ "$status" -eq 0 ]
    [ -f "$PROJECT/.omao/permissions.yaml" ]
    # Resolved chain with the seeded overlay must equal the base resolution.
    base=$(bash -c ". '$REPO_ROOT/scripts/lib/permissions.sh' && perms_resolve prod | jq -c '.deny'")
    overlay=$(bash -c ". '$REPO_ROOT/scripts/lib/permissions.sh' && perms_resolve_with_overlays prod '$PROJECT' | jq -c '.deny'")
    [ "$base" = "$overlay" ] || {
        echo "base=$base"; echo "overlay=$overlay"; return 1
    }
    # _meta.overlay_applied stays false because no rule actually fires.
    flag=$(bash -c ". '$REPO_ROOT/scripts/lib/permissions.sh' && perms_resolve_with_overlays prod '$PROJECT' | jq -r '._meta.overlay_applied'")
    [ "$flag" = "false" ]
}

@test "setup re-run preserves a hand-edited permissions.yaml" {
    env -i PATH="$PATH" HOME="$HOME" \
        OMA_NON_INTERACTIVE=1 OMA_HARNESS=claude-code \
        OMA_AWS_ACCOUNT=123456789012 OMA_AWS_REGION=ap-northeast-2 \
        OMA_AWS_ENV=sandbox OMA_AIDLC_PHASE=inception \
        OMA_APPROVAL_MODE=interactive OMA_BUDGET_USD=200 \
        OMA_OBSERVABILITY=langfuse-managed \
        bash -c "cd '$PROJECT' && '$OMA_BIN' setup --non-interactive --skip-install --skip-doctor" >/dev/null 2>&1
    # User customizes the overlay
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
deny:
  add:
    bash: ["my-team-only-pattern"]
YAML
    # Re-run setup
    run env -i PATH="$PATH" HOME="$HOME" \
        OMA_NON_INTERACTIVE=1 OMA_HARNESS=claude-code \
        OMA_AWS_ACCOUNT=123456789012 OMA_AWS_REGION=ap-northeast-2 \
        OMA_AWS_ENV=sandbox OMA_AIDLC_PHASE=inception \
        OMA_APPROVAL_MODE=interactive OMA_BUDGET_USD=200 \
        OMA_OBSERVABILITY=langfuse-managed \
        bash -c "cd '$PROJECT' && '$OMA_BIN' setup --non-interactive --skip-install --skip-doctor"
    [ "$status" -eq 0 ]
    grep -q 'my-team-only-pattern' "$PROJECT/.omao/permissions.yaml"
}

@test "setup --dry-run does not create files" {
    run env -i PATH="$PATH" HOME="$HOME" \
        OMA_NON_INTERACTIVE=1 \
        bash -c "cd '$PROJECT' && '$OMA_BIN' setup --dry-run"
    [ "$status" -eq 0 ]
    [ ! -f "$PROJECT/.omao/profile.yaml" ]
}
