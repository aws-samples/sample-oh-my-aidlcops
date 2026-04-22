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

# Emit JSON output
if command -v jq &>/dev/null; then
  jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{"additionalContext": $ctx}'
else
  # Fallback if jq not available
  echo "{\"additionalContext\": \"$ADDITIONAL_CONTEXT\"}"
fi
