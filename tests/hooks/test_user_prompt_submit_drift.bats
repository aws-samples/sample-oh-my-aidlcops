#!/usr/bin/env bats
# tests/hooks/test_user_prompt_submit_drift.bats
# Coverage for the new permission-overlay drift detection in
# hooks/user-prompt-submit.sh. The drift check runs only when no trigger
# keyword matched and no budget warning fired — so triggers still take
# precedence over the drift reminder.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$REPO_ROOT/hooks/user-prompt-submit.sh"
    PROJECT="$(mktemp -d)"
    mkdir -p "$PROJECT/.omao"
    # Minimal triggers.json — no keywords, so trigger detection won't fire
    # and the drift block becomes reachable on a plain prompt.
    cat > "$PROJECT/.omao/triggers.json" <<'JSON'
{ "triggers": [] }
JSON
    FAKE_HOME="$(mktemp -d)"
    mkdir -p "$FAKE_HOME/.claude"
    # Stale OMA sentinel — install ran a long time ago so any newly-touched
    # overlay below will look "newer".
    : > "$FAKE_HOME/.claude/.oma-permissions-applied-at"
    touch -t 202401010000 "$FAKE_HOME/.claude/.oma-permissions-applied-at"
}

teardown() {
    rm -rf "$PROJECT" "$FAKE_HOME"
}

# Run the hook with a plain prompt, env stubbed so drift can fire.
run_hook() {
    cd "$PROJECT"
    HOME="$FAKE_HOME" run bash -c "echo '$1' | bash '$HOOK'"
}

@test "drift line surfaces on every prompt while overlay is newer than settings" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
deny:
  add:
    bash: ["test-pattern"]
YAML
    run_hook 'just a normal question'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("OMA_PERMISSIONS_DRIFT")'
}

@test "no drift line when sentinel is newer than overlay" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    touch -t 202401010000 "$PROJECT/.omao/permissions.yaml"
    : > "$FAKE_HOME/.claude/.oma-permissions-applied-at"   # current mtime, newer

    run_hook 'just a normal question'
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        run jq -e '.hookSpecificOutput.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
        [ "$status" -eq 0 ]
    fi
}

@test "OMA_DISABLE_PERMISSIONS_DRIFT suppresses on prompt-submit" {
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    cd "$PROJECT"
    HOME="$FAKE_HOME" OMA_DISABLE_PERMISSIONS_DRIFT=1 run bash -c "echo 'q' | bash '$HOOK'"
    [ "$status" -eq 0 ]
    if [ -n "$output" ]; then
        run jq -e '.hookSpecificOutput.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
        [ "$status" -eq 0 ]
    fi
}

@test "trigger keyword takes precedence over drift" {
    # Re-author triggers.json so a keyword exists.
    cat > "$PROJECT/.omao/triggers.json" <<'JSON'
{
  "triggers": [
    {"id": "ag", "keywords": ["agenticops"], "context_required": [], "command": "/oma:agenticops", "description": "ops mode"}
  ]
}
JSON
    cat > "$PROJECT/.omao/permissions.yaml" <<'YAML'
version: 1
YAML
    run_hook 'launch agenticops now'
    [ "$status" -eq 0 ]
    # Trigger keyword wins: OMA_TRIGGER, not the drift keyword.
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("OMA_TRIGGER")'
    run jq -e '.hookSpecificOutput.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "no overlay file: hook is silent" {
    # Overlay doesn't exist — drift block must skip cleanly.
    run_hook 'plain prompt'
    [ "$status" -eq 0 ]
    # Either empty output or no drift mention.
    if [ -n "$output" ]; then
        run jq -e '.hookSpecificOutput.additionalContext | contains("OMA_PERMISSIONS_DRIFT") | not' <<<"$output"
        [ "$status" -eq 0 ]
    fi
}
