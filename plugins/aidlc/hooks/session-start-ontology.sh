#!/usr/bin/env bash
# session-start-ontology.sh — plugin-bundled SessionStart hook (#60).
#
# Injects a compact ontology-state block at session start so the agent begins
# aware of active Budgets, open Incidents, and pending Deployments. This is the
# runtime half of the correctness axis that /plugin install must deliver.
#
# SELF-CONTAINED BY DESIGN: unlike the repo-root hooks/session-start.sh (which
# also does Tier-0 mode + project-memory + permissions-drift and depends on
# scripts/lib/permissions.sh), this hook reads ONLY the project's
# .omao/ontology/ and has NO repo-root dependency, so it works verbatim from an
# installed plugin copy. Kill switch: OMA_DISABLE_ONTOLOGY=1.
#
# Emitted into the plugin's hooks/hooks.json (SessionStart) by oma-compile from
# the DSL `hooks.session-start` declaration. Do not hand-edit the hooks.json
# entry; edit the DSL and recompile.

set -euo pipefail

if [[ "${OMA_DISABLE_ONTOLOGY:-0}" == "1" ]]; then
  # Emit an empty-but-valid SessionStart payload so the harness sees a no-op.
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}\n'
  exit 0
fi

# Resolve the project directory. Claude Code passes CLAUDE_PROJECT_DIR to hooks
# (the cwd at `claude` startup); fall back to $PWD for other harnesses.
OMA_PROJ_DIR="${CLAUDE_PROJECT_DIR:-${OMA_PROJECT_DIR:-$PWD}}"
ONTOLOGY_DIR="$OMA_PROJ_DIR/.omao/ontology"

ADDITIONAL_CONTEXT=""

if command -v jq >/dev/null 2>&1 && [[ -d "$ONTOLOGY_DIR" ]]; then
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
    ADDITIONAL_CONTEXT="[OMA Ontology — active state]

$ONTOLOGY_BLOCK
Ground new entities against these before authoring. Query the ontology-wiki skill for definitions/enums."
  fi
fi

# Emit the SessionStart payload. A real JSON encoder is REQUIRED because the
# ontology files are user-editable and may contain quotes/newlines that would
# break naive shell-string interpolation and allow key injection.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
elif command -v python3 >/dev/null 2>&1; then
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT" python3 -c '
import json, os, sys
sys.stdout.write(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ["ADDITIONAL_CONTEXT"]
    }
}))
sys.stdout.write("\n")
'
else
  echo "session-start-ontology.sh: neither jq nor python3 available; refusing to emit unsafe JSON" >&2
  exit 1
fi
