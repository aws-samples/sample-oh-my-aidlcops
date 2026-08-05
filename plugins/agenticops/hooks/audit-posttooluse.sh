#!/usr/bin/env bash
# audit-posttooluse.sh — plugin-bundled PostToolUse audit hook (harness safety axis).
#
# Runs AFTER every tool call succeeds. Two jobs:
#   1. AUDIT (all tools): append one JSON-L line per call to
#      .omao/audit/tool-events.jsonl, conforming to
#      schemas/audit/tool-event.schema.json. This makes the audit trail a
#      property of the harness, not of the agent remembering to call the
#      audit-trail skill.
#   2. FEEDBACK (mutating tools only): return an additionalContext nudge so the
#      agent is reminded to record a semantic ontology event / check gates after
#      a state-changing action. PostToolUse cannot block (the tool already ran),
#      so this is guidance, not enforcement — see the PreToolUse enforcer for the
#      hard backstop.
#
# SELF-CONTAINED BY DESIGN (same contract as session-start-ontology.sh /
# stop-gate.sh): writes only under the project's .omao/ and has NO repo-root or
# jsonschema dependency, so it works verbatim from an installed plugin copy and
# emits schema-conforming lines with just jq (python3 fallback).
#
# CONTROLS:
#   OMA_DISABLE_AUDIT=1   kill switch — pass through, write nothing.
#
# A real JSON encoder is REQUIRED: tool inputs are attacker-influenced
# (file contents, commands) and naive shell interpolation would corrupt the
# JSON-L line or the emitted hook payload.
#
# Emitted into hooks/hooks.json (PostToolUse) by oma-compile from the DSL
# `hooks.post-tool-use` declaration. Do not hand-edit that entry; edit the DSL
# and recompile.

set -euo pipefail

_emit_pass() {
  # Valid no-op PostToolUse payload (no feedback).
  printf '{}\n'
  exit 0
}

# Kill switch.
if [[ "${OMA_DISABLE_AUDIT:-0}" == "1" ]]; then
  _emit_pass
fi

# A JSON encoder is mandatory. Without jq we cannot safely parse the event or
# emit a conforming line, so we pass through rather than write corrupt audit.
if ! command -v jq >/dev/null 2>&1; then
  _emit_pass
fi

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && _emit_pass

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
[[ -z "$TOOL" ]] && _emit_pass

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"
# Edit/Write/Read use file_path; NotebookEdit uses notebook_path.
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null || echo "")"

# --- classify: is this a state-mutating call? -------------------------------
# Mutating pattern rules. First match wins and names the rule for the record.
CLASSIFICATION="benign"
MATCHED_RULE=""

case "$TOOL" in
  Write|NotebookEdit)
    CLASSIFICATION="mutating"; MATCHED_RULE="file-write" ;;
  Edit)
    CLASSIFICATION="mutating"; MATCHED_RULE="file-edit" ;;
  Bash)
    # Ordered command-pattern checks. Kept intentionally broad; the audit line
    # records which rule fired so downstream review can tune.
    if   [[ "$COMMAND" =~ kubectl[[:space:]]+(apply|create|delete|edit|patch|replace|scale|autoscale|set|rollout|expose|run|annotate|label|taint|cordon|drain|uncordon) ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="kubectl-mutating"
    elif [[ "$COMMAND" =~ aws[[:space:]]+[a-z0-9-]+[[:space:]]+(delete|put|update|create|remove|terminate|deregister|detach|disable|modify|reboot|stop)- ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="aws-cli-mutating"
    elif [[ "$COMMAND" =~ terraform[[:space:]]+(apply|destroy) ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="terraform-mutating"
    elif [[ "$COMMAND" =~ helm[[:space:]]+(install|upgrade|uninstall|delete|rollback) ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="helm-mutating"
    elif [[ "$COMMAND" =~ (^|[[:space:]\;\|&])(rm|mv|cp|dd|truncate|chmod|chown)[[:space:]] ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="fs-mutating"
    elif [[ "$COMMAND" =~ git[[:space:]]+(push|reset|clean|rebase) ]]; then
      CLASSIFICATION="mutating"; MATCHED_RULE="git-mutating"
    fi
    ;;
esac

FEEDBACK_EMITTED=false
[[ "$CLASSIFICATION" == "mutating" ]] && FEEDBACK_EMITTED=true

# --- append the audit line (all tools) --------------------------------------
OMA_PROJ_DIR="${CLAUDE_PROJECT_DIR:-${OMA_PROJECT_DIR:-$PWD}}"
AUDIT_DIR="$OMA_PROJ_DIR/.omao/audit"
AUDIT_FILE="$AUDIT_DIR/tool-events.jsonl"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Truncate the command excerpt to keep lines small and within the schema bound.
COMMAND_EXCERPT="${COMMAND:0:512}"

# Build the record with jq so every value is correctly escaped. Optional keys
# are dropped when empty to keep the line minimal and schema-conforming.
mkdir -p "$AUDIT_DIR" 2>/dev/null || true
if RECORD="$(jq -cn \
    --arg ts "$TS" \
    --arg tool "$TOOL" \
    --arg classification "$CLASSIFICATION" \
    --arg matched_rule "$MATCHED_RULE" \
    --arg command_excerpt "$COMMAND_EXCERPT" \
    --arg file_path "$FILE_PATH" \
    --arg session_id "$SESSION_ID" \
    --arg cwd "$CWD" \
    --argjson feedback_emitted "$FEEDBACK_EMITTED" '
      {ts: $ts, tool: $tool, classification: $classification, feedback_emitted: $feedback_emitted}
      + (if $matched_rule    != "" then {matched_rule: $matched_rule}       else {} end)
      + (if $command_excerpt != "" then {command_excerpt: $command_excerpt} else {} end)
      + (if $file_path       != "" then {file_path: $file_path}             else {} end)
      + (if $session_id      != "" then {session_id: $session_id}           else {} end)
      + (if $cwd             != "" then {cwd: $cwd}                         else {} end)
    ' 2>/dev/null)"; then
  # Append-only; open(a) is atomic for small writes on POSIX.
  printf '%s\n' "$RECORD" >> "$AUDIT_FILE" 2>/dev/null || true
fi

# --- feedback (mutating only) -----------------------------------------------
if [[ "$CLASSIFICATION" != "mutating" ]]; then
  _emit_pass
fi

TARGET="$FILE_PATH"
[[ -z "$TARGET" && -n "$COMMAND_EXCERPT" ]] && TARGET="$COMMAND_EXCERPT"

CONTEXT="[OMA audit] Recorded a state-changing $TOOL call (rule: ${MATCHED_RULE:-n/a}) to .omao/audit/tool-events.jsonl.
Target: ${TARGET:-n/a}
If this mutated an ontology entity (Deployment, Incident, ...), record the semantic event with the audit-trail skill, and confirm no phase gate is blocked before proceeding."

jq -n --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
