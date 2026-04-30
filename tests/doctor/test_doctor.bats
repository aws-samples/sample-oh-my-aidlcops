#!/usr/bin/env bats
# tests/doctor/test_doctor.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    OMA_BIN="$REPO_ROOT/bin/oma"
    PROJECT="$(mktemp -d)"
    export NO_COLOR=1 OMA_QUIET=1
}

teardown() {
    rm -rf "$PROJECT"
}

@test "doctor --json emits schema-valid report" {
    run "$OMA_BIN" doctor --json --project "$PROJECT"
    # exit 0..2 are all allowed on a developer box
    [ "$status" -le 2 ]
    echo "$output" | jq -e '
        .version == "1" and
        (.summary | (.pass + .warn + .fail) >= 1) and
        (.probes | length >= 10)' >/dev/null
}

@test "doctor pretty output mentions every probe label" {
    run "$OMA_BIN" doctor --project "$PROJECT"
    [ "$status" -le 2 ]
    [[ "$output" == *"Bash >= 4"* ]]
    [[ "$output" == *"jq installed"* ]]
    [[ "$output" == *"AWS credentials"* ]]
    [[ "$output" == *"MCP server versions pinned"* ]]
    [[ "$output" == *"Summary:"* ]]
}
