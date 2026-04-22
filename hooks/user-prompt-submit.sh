#!/usr/bin/env bash
# user-prompt-submit.sh — OMA Tier-0 keyword trigger detector
# Run: chmod +x hooks/user-prompt-submit.sh after install-claude.sh
#
# Reads user prompt from stdin, matches against .omao/triggers.json,
# and emits additionalContext JSON if a trigger keyword is detected.

set -euo pipefail

# Respect kill switch
if [[ "${OMA_DISABLE_TRIGGERS:-0}" == "1" ]]; then
  exit 0
fi

# Locate triggers.json (repo-relative or user project)
TRIGGERS_JSON=""
if [[ -f ".omao/triggers.json" ]]; then
  TRIGGERS_JSON=".omao/triggers.json"
elif [[ -f "./.omao/triggers.json" ]]; then
  TRIGGERS_JSON="./.omao/triggers.json"
fi

# Graceful exit if triggers.json missing
if [[ -z "$TRIGGERS_JSON" ]]; then
  exit 0
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
  echo "[OMA] Warning: jq not found, trigger detection disabled" >&2
  exit 0
fi

# Read stdin (Claude Code passes prompt as JSON)
INPUT=$(cat)

# Extract prompt text (handle both direct string and JSON wrapper)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .message // .' 2>/dev/null || echo "$INPUT")

# Convert to lowercase for case-insensitive matching
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Parse triggers.json
TRIGGERS=$(jq -c '.triggers[]' "$TRIGGERS_JSON" 2>/dev/null || echo "")

if [[ -z "$TRIGGERS" ]]; then
  exit 0
fi

# Iterate through triggers
while IFS= read -r trigger; do
  # Extract fields
  TRIGGER_ID=$(echo "$trigger" | jq -r '.id')
  KEYWORDS=$(echo "$trigger" | jq -r '.keywords[]' 2>/dev/null || echo "")
  CONTEXT_REQUIRED=$(echo "$trigger" | jq -r '.context_required[]?' 2>/dev/null || echo "")
  COMMAND=$(echo "$trigger" | jq -r '.command')
  DESCRIPTION=$(echo "$trigger" | jq -r '.description')

  # Check if any keyword matches (with word boundaries)
  KEYWORD_MATCH=0
  MATCHED_KEYWORD=""
  while IFS= read -r keyword; do
    [[ -z "$keyword" ]] && continue
    keyword_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
    # Use grep with word boundaries for single-word keywords
    # For slash commands or multi-word, use substring match
    if [[ "$keyword_lower" == *" "* ]] || [[ "$keyword_lower" == /*:* ]]; then
      # Multi-word or slash command - use substring match
      if [[ "$PROMPT_LOWER" == *"$keyword_lower"* ]]; then
        KEYWORD_MATCH=1
        MATCHED_KEYWORD="$keyword_lower"
        break
      fi
    else
      # Single word - use word boundary matching
      if echo "$PROMPT_LOWER" | grep -qw "$keyword_lower"; then
        KEYWORD_MATCH=1
        MATCHED_KEYWORD="$keyword_lower"
        break
      fi
    fi
  done <<< "$KEYWORDS"

  [[ "$KEYWORD_MATCH" -eq 0 ]] && continue

  # Check context requirements (skip if explicit slash command was used)
  CONTEXT_MATCH=1
  if [[ "$MATCHED_KEYWORD" == /*:* ]]; then
    # Explicit slash command - bypass context requirements
    CONTEXT_MATCH=1
  elif [[ -n "$CONTEXT_REQUIRED" ]]; then
    while IFS= read -r ctx; do
      [[ -z "$ctx" ]] && continue
      ctx_lower=$(echo "$ctx" | tr '[:upper:]' '[:lower:]')
      if [[ "$PROMPT_LOWER" != *"$ctx_lower"* ]]; then
        CONTEXT_MATCH=0
        break
      fi
    done <<< "$CONTEXT_REQUIRED"
  fi

  # If both keyword and context match, emit additionalContext
  if [[ "$KEYWORD_MATCH" -eq 1 && "$CONTEXT_MATCH" -eq 1 ]]; then
    ADDITIONAL_CONTEXT="[MAGIC KEYWORD: OMA_TRIGGER]

Trigger detected: $TRIGGER_ID
Suggested command: $COMMAND
Description: $DESCRIPTION

Invoke this command or proceed with the user's request using the relevant Tier-0 workflow."

    jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{"additionalContext": $ctx}'
    exit 0
  fi
done <<< "$TRIGGERS"

# No match found
exit 0
