#!/usr/bin/env bats
# tests/hooks/test_audit_posttooluse.bats
#
# Behavioral tests for the plugin-bundled PostToolUse audit hook. It records
# every tool call to .omao/audit/tool-events.jsonl and returns an
# additionalContext nudge only for state-changing calls.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/plugins/agenticops/hooks/audit-posttooluse.sh"
    PROJECT="$(mktemp -d)"
    LOG="$PROJECT/.omao/audit/tool-events.jsonl"
}

teardown() {
    rm -rf "$PROJECT"
}

_run() {
    run env CLAUDE_PROJECT_DIR="$PROJECT" bash "$HOOK" <<<"$1"
}

@test "benign Read: recorded, no feedback" {
    _run '{"tool_name":"Read","tool_input":{"file_path":"/x/README.md"}}'
    [ "$status" -eq 0 ]
    # No additionalContext (empty payload).
    echo "$output" | jq -e 'has("hookSpecificOutput") | not' >/dev/null
    [ -f "$LOG" ]
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.tool == "Read" and .classification == "benign"' >/dev/null
}

@test "mutating kubectl apply: recorded + feedback" {
    _run '{"tool_name":"Bash","tool_input":{"command":"kubectl apply -f m.yaml"}}'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("state-changing")' >/dev/null
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.classification == "mutating" and .matched_rule == "kubectl-mutating"' >/dev/null
}

@test "Write: classified mutating with feedback" {
    _run '{"tool_name":"Write","tool_input":{"file_path":"/x/main.py"}}'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.tool == "Write" and .matched_rule == "file-write" and .file_path == "/x/main.py"' >/dev/null
}

@test "benign bash (ls): recorded, no feedback" {
    _run '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'has("hookSpecificOutput") | not' >/dev/null
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.classification == "benign"' >/dev/null
}

@test "aws delete: classified mutating" {
    _run '{"tool_name":"Bash","tool_input":{"command":"aws s3api delete-bucket --bucket x"}}'
    [ "$status" -eq 0 ]
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.matched_rule == "aws-cli-mutating"' >/dev/null
}

@test "terraform destroy: classified mutating" {
    _run '{"tool_name":"Bash","tool_input":{"command":"terraform destroy -auto-approve"}}'
    [ "$status" -eq 0 ]
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.matched_rule == "terraform-mutating"' >/dev/null
}

@test "OMA_DISABLE_AUDIT=1: no record, no feedback" {
    run env CLAUDE_PROJECT_DIR="$PROJECT" OMA_DISABLE_AUDIT=1 bash "$HOOK" \
        <<<'{"tool_name":"Write","tool_input":{"file_path":"/x/y"}}'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'has("hookSpecificOutput") | not' >/dev/null
    [ ! -f "$LOG" ]
}

@test "crafted command with quotes/newline: output and log stay valid JSON" {
    _run '{"tool_name":"Bash","tool_input":{"command":"echo \"evil\" && rm -rf /tmp/x\nnl"}}'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null
    # The appended line must parse as a single JSON object.
    run tail -n1 "$LOG"
    echo "$output" | jq -e '.tool == "Bash"' >/dev/null
}

@test "every recorded line has required fields" {
    _run '{"tool_name":"Read","tool_input":{"file_path":"/a"}}'
    _run '{"tool_name":"Write","tool_input":{"file_path":"/b"}}'
    _run '{"tool_name":"Bash","tool_input":{"command":"kubectl delete pod x"}}'
    run wc -l < "$LOG"
    [ "$output" -eq 3 ]
    # Each line must carry ts, tool, classification.
    while IFS= read -r line; do
        echo "$line" | jq -e 'has("ts") and has("tool") and has("classification")' >/dev/null
    done < "$LOG"
}
