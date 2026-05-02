#!/usr/bin/env bats
# tests/installer/test_enterprise_smoke.bats
# Smoke tests for OMA enterprise flags. Exercises `oma doctor --enterprise`,
# `oma compile --strict-enterprise`, and `oma validate` in a clean checkout.
# These probes catch breakage in the entity compiler, strict-mode gates, or
# OPA policy loading before they reach production.

setup() {
    OMA_REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export OMA_REPO_ROOT
    export NO_COLOR=1
    export OMA_QUIET=1
}

teardown() {
    # no temp files to clean up; all commands run in-place
    true
}

@test "oma doctor --enterprise exits 0 and reports 8 probes OK" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/bin/oma" doctor --enterprise
    [ "$status" -eq 0 ]
    [[ "$output" == *"8 probes OK"* ]] || {
        echo "expected '8 probes OK' in output:"
        echo "$output"
        return 1
    }
}

@test "oma compile --strict-enterprise exits 0 on clean repo" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/bin/oma" compile --strict-enterprise
    [ "$status" -eq 0 ]
}

@test "oma validate accepts a .mcp.json path gracefully" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    # .mcp.json is not an entity YAML, so validate should handle it without
    # crashing. We check exit 0 (graceful fallback), not exact message.
    run bash "$OMA_REPO_ROOT/bin/oma" validate \
        "$OMA_REPO_ROOT/plugins/ai-infra/.mcp.json"
    [ "$status" -eq 0 ]
}
