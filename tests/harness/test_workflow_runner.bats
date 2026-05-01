#!/usr/bin/env bats
# tests/harness/test_workflow_runner.bats — smoke tests for oma run-workflow.

setup() {
    export OMA_REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
    export OMA_QUIET=1
    export NO_COLOR=1
}

@test "run-workflow on agentic-platform platform-bootstrap returns clean DAG" {
    run bash "$OMA_REPO_ROOT/scripts/oma/run-workflow.sh" agentic-platform platform-bootstrap
    [ "$status" -eq 0 ]
    [[ "$output" =~ "execution order: preflight -> provision -> verify" ]]
    [[ "$output" =~ "agent_ref: agentic-platform" ]]
    [[ "$output" =~ "skill_ref: agentic-eks-bootstrap" ]]
}

@test "run-workflow with missing workflow name exits 1" {
    run bash "$OMA_REPO_ROOT/scripts/oma/run-workflow.sh" agentic-platform nonexistent-workflow
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "run-workflow on plugin with no workflows exits 1 with helpful error" {
    run bash "$OMA_REPO_ROOT/scripts/oma/run-workflow.sh" agenticops any-workflow
    [ "$status" -eq 1 ]
    [[ "$output" =~ "declares no workflows" ]]
}

@test "run-workflow with missing plugin exits 1" {
    run bash "$OMA_REPO_ROOT/scripts/oma/run-workflow.sh" nonexistent-plugin some-workflow
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "run-workflow prints usage when called with insufficient args" {
    run bash "$OMA_REPO_ROOT/scripts/oma/run-workflow.sh"
    [ "$status" -eq 64 ]
    [[ "$output" =~ "Usage:" ]]
}
