#!/usr/bin/env bats
# tests/installer/test_enterprise_status.bats — smoke tests for
# scripts/oma/enterprise-status.sh. We exercise pretty + JSON output
# paths and make sure the stage list stays 6 entries long.

setup() {
    OMA_REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export OMA_REPO_ROOT
    export NO_COLOR=1
    export OMA_QUIET=1
}

@test "enterprise-status pretty mode lists 6 stages" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/scripts/oma/enterprise-status.sh"
    # Stage counters are ordered Stage 1..Stage 6; assert each line appears.
    for stage in 1 2 3 4 5 6; do
        [[ "$output" == *"Stage $stage:"* ]] || {
            echo "missing Stage $stage in output:"
            echo "$output"
            return 1
        }
    done
    [[ "$output" == *"phased adoption:"* ]]
}

@test "enterprise-status --json emits parseable JSON with required keys" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/scripts/oma/enterprise-status.sh" --json
    [ -n "$output" ]
    # Feed the output back through python to confirm structure.
    python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert "generated_at" in d
assert "overall_ok" in d
assert isinstance(d.get("stages"), list) and len(d["stages"]) == 6
assert isinstance(d.get("completion_pct"), int)
assert isinstance(d.get("probe_failures"), list)
PY
}

@test "enterprise-status writes .omao/status.json archive" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/scripts/oma/enterprise-status.sh" --json
    [ -f "$OMA_REPO_ROOT/.omao/status.json" ]
}

@test "enterprise-status unknown flag exits 2" {
    if ! command -v python3 >/dev/null; then
        skip "python3 not available"
    fi
    run bash "$OMA_REPO_ROOT/scripts/oma/enterprise-status.sh" --whatever
    [ "$status" -eq 2 ]
}
