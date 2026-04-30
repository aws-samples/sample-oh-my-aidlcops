#!/usr/bin/env bats
# tests/profile/test_profile_roundtrip.bats
# Profile read/write/validate lifecycle.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export NO_COLOR=1 OMA_QUIET=1
    TMPDIR_P="$(mktemp -d)"
    # shellcheck disable=SC1091
    . "$REPO_ROOT/scripts/lib/profile.sh"
    cp "$REPO_ROOT/templates/profile/profile.yaml.tmpl" "$TMPDIR_P/profile.yaml"
    # Substitute placeholders with valid test values.
    sed -i.bak \
        -e 's|{{CREATED_AT}}|2026-04-30T02:00:00Z|' \
        -e 's|{{HARNESS_PRIMARY}}|claude-code|' \
        -e 's|{{HARNESS_SECONDARY}}|null|' \
        -e 's|{{AWS_ACCOUNT_ID}}|123456789012|' \
        -e 's|{{AWS_REGION}}|ap-northeast-2|' \
        -e 's|{{AWS_PROFILE_NAME}}|default|' \
        -e 's|{{AWS_ENVIRONMENT}}|sandbox|' \
        -e 's|{{AIDLC_ENTRY_PHASE}}|inception|' \
        -e 's|{{AIDLC_STRICT_GATES}}|false|' \
        -e 's|{{APPROVAL_MODE}}|interactive|' \
        -e 's|{{APPROVAL_BLAST_RADIUS}}|single-account|' \
        -e 's|{{BUDGET_MONTHLY_USD}}|200|' \
        -e 's|{{BUDGET_WARN_PCT}}|80|' \
        -e 's|{{BUDGET_BLOCK_PCT}}|100|' \
        -e 's|{{OBSERVABILITY_MODE}}|langfuse-managed|' \
        -e 's|{{OBSERVABILITY_ENDPOINT}}|null|' \
        -e 's|{{STAR_CONFIRMED}}|true|' \
        "$TMPDIR_P/profile.yaml"
    rm -f "$TMPDIR_P/profile.yaml.bak"
}

teardown() {
    rm -rf "$TMPDIR_P"
}

@test "rendered template validates" {
    run profile_validate "$TMPDIR_P/profile.yaml"
    if [ "$status" -ne 0 ]; then
        cat "$TMPDIR_P/profile.yaml"
        echo "---"
        echo "$output"
    fi
    [ "$status" -eq 0 ]
}

@test "profile_read extracts nested field" {
    result="$(profile_read "$TMPDIR_P/profile.yaml" '.aws.region')"
    [ "$result" = "ap-northeast-2" ]
}

@test "profile_write updates nested field" {
    profile_write "$TMPDIR_P/profile.yaml" .aws.region=us-east-1
    result="$(profile_read "$TMPDIR_P/profile.yaml" '.aws.region')"
    [ "$result" = "us-east-1" ]
}

@test "missing required field fails validation" {
    # Remove the required `harness` key
    sed -i.bak '/^harness:/,/^aws:/{/^aws:/!d;}' "$TMPDIR_P/profile.yaml"
    rm -f "$TMPDIR_P/profile.yaml.bak"
    run profile_validate "$TMPDIR_P/profile.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"'harness' is a required property"* ]] || \
    [[ "$output" == *"harness"* ]]
}

@test "invalid aws.account_id rejected" {
    profile_write "$TMPDIR_P/profile.yaml" .aws.account_id=abc
    run profile_validate "$TMPDIR_P/profile.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"account_id"* ]]
}

@test "invalid observability.mode rejected" {
    profile_write "$TMPDIR_P/profile.yaml" .observability.mode=skynet
    run profile_validate "$TMPDIR_P/profile.yaml"
    [ "$status" -ne 0 ]
    [[ "$output" == *"mode"* ]]
}
