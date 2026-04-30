#!/usr/bin/env bash
# scripts/lib/jq-ontology.sh — hot-path jq helpers for reading seed ontology
# instances from a project's .omao/ontology/ directory. Stays side-effect free.
#
# Designed for use inside hooks where Python startup cost is too high.
# All functions exit 0 and emit empty output when the target directory/file
# is missing — the caller decides what to do with an empty result.

if [ "${__OMA_JQ_ONTOLOGY_LOADED:-0}" = 1 ]; then return 0; fi
__OMA_JQ_ONTOLOGY_LOADED=1

# ontology_list_budgets <project-dir>
# Emits JSON array of {id, scope, limit_usd, period}. One line per entry.
ontology_list_budgets() {
    dir="${1:-$PWD}/.omao/ontology/budgets"
    [ -d "$dir" ] || return 0
    find "$dir" -type f -name '*.json' -maxdepth 1 | while IFS= read -r f; do
        jq -c '{id, scope, scope_ref, limit_usd, period, action_on_breach}' "$f" 2>/dev/null
    done
}

# ontology_list_open_incidents <project-dir>
ontology_list_open_incidents() {
    dir="${1:-$PWD}/.omao/ontology/incidents"
    [ -d "$dir" ] || return 0
    find "$dir" -type f -name '*.json' -maxdepth 1 | while IFS= read -r f; do
        jq -c 'select(.approval_state == "proposed" or .approval_state == "draft") | {id, severity, alarm_source, approval_state}' "$f" 2>/dev/null
    done
}

# ontology_list_pending_deployments <project-dir>
ontology_list_pending_deployments() {
    dir="${1:-$PWD}/.omao/ontology/deployments"
    [ -d "$dir" ] || return 0
    find "$dir" -type f -name '*.json' -maxdepth 1 | while IFS= read -r f; do
        jq -c 'select(.approval_state == "proposed" or .approval_state == "draft") | {id, target, approval_state, blast_radius}' "$f" 2>/dev/null
    done
}
