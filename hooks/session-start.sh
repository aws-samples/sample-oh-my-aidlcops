#!/usr/bin/env bash
# session-start.sh — OMA session initialization hook
#
# Runs at session start to inject project context:
# - Active Tier-0 mode reminder
# - Project memory
# - Available OMA commands

set -euo pipefail

# Respect kill switch
if [[ "${OMA_DISABLE_TRIGGERS:-0}" == "1" ]]; then
  exit 0
fi

ADDITIONAL_CONTEXT=""

# Check for active Tier-0 mode
if [[ -f ".omao/state/active-mode" ]]; then
  ACTIVE_MODE=$(cat ".omao/state/active-mode" 2>/dev/null || echo "")
  if [[ -n "$ACTIVE_MODE" ]]; then
    ADDITIONAL_CONTEXT+="[OMA Session Context]

Active Tier-0 Mode: $ACTIVE_MODE

This mode is currently running. Use /oma:cancel to terminate if needed.

"
  fi
fi

# Load project memory if exists
if [[ -f ".omao/project-memory.json" ]]; then
  PROJECT_MEMORY=$(cat ".omao/project-memory.json" 2>/dev/null || echo "")
  if [[ -n "$PROJECT_MEMORY" ]]; then
    ADDITIONAL_CONTEXT+="Project Memory:
$PROJECT_MEMORY

"
  fi
fi

# Add OMA command reference
ADDITIONAL_CONTEXT+="Available OMA Tier-0 Commands:
- /oma:autopilot           — AIDLC full-loop autopilot (Inception→Construction→Operations)
- /oma:aidlc-loop          — Single feature AIDLC one-pass
- /oma:inception           — Phase 1 only (requirements, stories, workflow planning)
- /oma:construction        — Phase 2 only (component design, codegen, TDD)
- /oma:agenticops          — Operations mode (continuous-eval + incident-response + cost-governance)
- /oma:self-improving      — Feedback loop runner (Langfuse traces → skill/prompt improvement PR)
- /oma:platform-bootstrap  — Agentic AI Platform 5-checkpoint bootstrap on EKS
- /oma:review              — AIDLC artifact review (ADR, spec, design, PR)
- /oma:cancel              — Terminate active Tier-0 mode

Keyword triggers are active. Type keywords like 'autopilot', 'agenticops', 'inception', etc. to invoke workflows."

# Emit JSON output.
#
# CRITICAL: ADDITIONAL_CONTEXT is built from files on disk
# (.omao/state/active-mode, .omao/project-memory.json) that may contain double
# quotes, backslashes, newlines, or control characters. Naive
# `echo "{\"additionalContext\": \"$VAR\"}"` would break the emitted JSON and,
# worse, let a crafted state file inject arbitrary keys into the session
# context. We REQUIRE a real JSON encoder: jq is preferred, Python 3 is an
# acceptable fallback. We never fall back to shell-string interpolation.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{"additionalContext": $ctx}'
elif command -v python3 >/dev/null 2>&1; then
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT" python3 -c '
import json, os, sys
sys.stdout.write(json.dumps({"additionalContext": os.environ["ADDITIONAL_CONTEXT"]}))
sys.stdout.write("\n")
'
elif command -v python >/dev/null 2>&1; then
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT" python -c '
import json, os, sys
sys.stdout.write(json.dumps({"additionalContext": os.environ["ADDITIONAL_CONTEXT"]}))
sys.stdout.write("\n")
'
else
  echo "session-start.sh: neither jq nor python is available; refusing to emit unsafe JSON" >&2
  exit 1
fi
