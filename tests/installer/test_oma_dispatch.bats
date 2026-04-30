#!/usr/bin/env bats
# tests/installer/test_oma_dispatch.bats
# Smoke tests for the `oma` dispatcher. Guards against regressions in argv
# parsing and subcommand routing. Does NOT test subcommand internals — that
# lives with each subcommand's own test file.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    OMA_BIN="$REPO_ROOT/bin/oma"
    export NO_COLOR=1
    export OMA_QUIET=1
}

@test "oma help exits 0 and mentions every subcommand" {
    run "$OMA_BIN" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"oma — AIDLC × AgenticOps easy button"* ]]
    for name in setup doctor compile status upgrade uninstall help version; do
        [[ "$output" == *"$name"* ]] || {
            echo "missing subcommand in help: $name"
            return 1
        }
    done
}

@test "oma --help is a synonym" {
    run "$OMA_BIN" --help
    [ "$status" -eq 0 ]
}

@test "oma version prints oma plus a semver-like string" {
    run env OMA_REPO_ROOT="$REPO_ROOT" "$OMA_BIN" version
    if [ "$status" -ne 0 ]; then
        echo "exit=$status"
        echo "output=[$output]"
    fi
    [ "$status" -eq 0 ]
    if ! echo "$output" | grep -Eq '^oma[[:space:]][0-9]+\.[0-9]+\.[0-9]+'; then
        echo "actual output: [$output]"
        echo "marketplace.json head:"
        head -8 "$REPO_ROOT/.claude-plugin/marketplace.json"
        return 1
    fi
}

@test "oma with no args prints help" {
    run "$OMA_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: oma"* ]]
}

@test "oma unknown-subcommand exits 64 (EX_USAGE)" {
    run "$OMA_BIN" definitely-not-a-real-command
    [ "$status" -eq 64 ]
    [[ "$output" == *"unknown subcommand"* ]]
}

@test "oma setup --dry-run exits 0 in stub build" {
    run "$OMA_BIN" setup --dry-run
    [ "$status" -eq 0 ]
}

@test "oma doctor --json emits valid JSON (stub or real)" {
    run "$OMA_BIN" doctor --json
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 2 ]
    echo "$output" | jq -e '.summary | (.pass + .warn + .fail) >= 0' >/dev/null
}

@test "oma compile --check does not error on empty plugin set" {
    run "$OMA_BIN" compile --check
    # exit 0 when no plugins with DSL yet; exit 1 on drift, but this
    # test only cares the dispatcher wired through.
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "bin/oma is executable" {
    [ -x "$OMA_BIN" ]
}
