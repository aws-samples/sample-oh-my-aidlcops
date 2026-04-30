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

# ----- Ontology status injection ---------------------------------------------
# Reads .omao/ontology/ and appends a compact status block so the session
# starts with awareness of active budgets, open incidents, and pending
# deployments. Kill switch: OMA_DISABLE_ONTOLOGY=1.
if [[ "${OMA_DISABLE_ONTOLOGY:-0}" != "1" ]] && command -v jq >/dev/null 2>&1; then
  ONTOLOGY_DIR=".omao/ontology"
  if [[ -d "$ONTOLOGY_DIR" ]]; then
    ONTOLOGY_BLOCK=""

    if [[ -d "$ONTOLOGY_DIR/budgets" ]]; then
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        line=$(jq -r '"Budget \(.id) [\(.scope):\(.scope_ref // "-")] limit=$\(.limit_usd)/\(.period), action=\(.action_on_breach)"' "$f" 2>/dev/null || true)
        [[ -n "$line" ]] && ONTOLOGY_BLOCK+="  - $line"$'\n'
      done < <(find "$ONTOLOGY_DIR/budgets" -maxdepth 1 -type f -name '*.json')
    fi

    if [[ -d "$ONTOLOGY_DIR/incidents" ]]; then
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        line=$(jq -r 'select(.approval_state == "proposed" or .approval_state == "open" or .approval_state == "draft") | "Incident \(.id) sev=\(.severity) approval=\(.approval_state) src=\(.alarm_source)"' "$f" 2>/dev/null || true)
        [[ -n "$line" ]] && ONTOLOGY_BLOCK+="  - $line"$'\n'
      done < <(find "$ONTOLOGY_DIR/incidents" -maxdepth 1 -type f -name '*.json')
    fi

    if [[ -d "$ONTOLOGY_DIR/deployments" ]]; then
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        line=$(jq -r 'select(.approval_state == "proposed" or .approval_state == "draft") | "Deployment \(.id) target=\(.target) state=\(.approval_state) blast=\(.blast_radius // "-")"' "$f" 2>/dev/null || true)
        [[ -n "$line" ]] && ONTOLOGY_BLOCK+="  - $line"$'\n'
      done < <(find "$ONTOLOGY_DIR/deployments" -maxdepth 1 -type f -name '*.json')
    fi

    if [[ -n "$ONTOLOGY_BLOCK" ]]; then
      ADDITIONAL_CONTEXT+="[OMA Ontology]

$ONTOLOGY_BLOCK
"
    fi
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
