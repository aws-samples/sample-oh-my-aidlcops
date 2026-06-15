#!/usr/bin/env bash
# scripts/oma/validate.sh — validate an ontology entity (Deployment / Incident /
# Budget / Risk / Agent / Skill / Spec / ADR) YAML/JSON file against its schema.
#
# Usage:
#   oma validate <path-to-entity.yaml> [--plugin <plugin-name>]
#
# Behaviour:
#   1. Loads <entity> and validates it against the matching ontology schema.
#   2. Exit code: 0 if schema-valid, 1 on schema violation.
#
# Runtime tool-call enforcement is NOT done here. It is compiled from each
# plugin's `policies:` block into a PreToolUse hook (hooks/enforce.py +
# hooks/harness-rules.json) — pure Claude Code, no external policy engine.

set -euo pipefail

die() { printf "[oma validate] %s\n" "$*" >&2; exit 1; }
warn() { printf "[oma validate] %s\n" "$*" >&2; }

OMA_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENTITY_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        # --plugin is accepted for backward compatibility and ignored; policy
        # enforcement no longer happens here (see header).
        --plugin) shift 2 ;;
        -h|--help)
            sed -n '2,14p' "$0" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        -*) die "unknown flag: $1" ;;
        *)
            if [[ -z "$ENTITY_FILE" ]]; then
                ENTITY_FILE="$1"; shift
            else
                die "extra argument: $1"
            fi
            ;;
    esac
done

if [[ -z "$ENTITY_FILE" ]]; then
    die "usage: oma validate <entity.yaml> [--plugin <plugin-name>]"
fi
if [[ ! -f "$ENTITY_FILE" ]]; then
    die "entity file not found: $ENTITY_FILE"
fi

# ----- Schema validation (shell out to python for consistent jsonschema) ----
if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required"
fi

python3 - "$OMA_ROOT" "$ENTITY_FILE" <<'PY'
import json, sys, re
from pathlib import Path

import yaml
from jsonschema import Draft7Validator, Draft202012Validator, RefResolver

repo_root = Path(sys.argv[1])
entity_path = Path(sys.argv[2])

data = yaml.safe_load(entity_path.read_text(encoding="utf-8"))

# Entity type detection heuristics (order matters for specificity)
schema_name = None
validator_class = Draft7Validator

if isinstance(data, dict):
    entity_id = data.get("id", "")
    top_keys = set(data.keys())

    # Spec: id matches ^spec-[a-z0-9-]+$ (Draft 2020-12)
    if re.match(r"^spec-[a-z0-9-]+$", entity_id):
        schema_name = "spec.schema.json"
        validator_class = Draft202012Validator
    # ADR: id matches ^adr-[0-9]{4}-[a-z0-9-]+$ (Draft 2020-12)
    elif re.match(r"^adr-[0-9]{4}-[a-z0-9-]+$", entity_id):
        schema_name = "adr.schema.json"
        validator_class = Draft202012Validator
    # Deployment: has target + artifact + approval_state (Draft-07)
    elif {"target", "artifact", "approval_state"} <= top_keys:
        schema_name = "deployment.schema.json"
    # Incident: has severity + alarm_source (Draft-07)
    elif {"severity", "alarm_source"} <= top_keys:
        schema_name = "incident.schema.json"
    # Budget: has scope + limit_usd (Draft-07)
    elif {"scope", "limit_usd"} <= top_keys:
        schema_name = "budget.schema.json"
    # Risk: has category + likelihood + impact (Draft-07)
    elif {"category", "likelihood", "impact"} <= top_keys:
        schema_name = "risk.schema.json"
    # Agent: has runtime (Draft-07)
    elif "runtime" in top_keys and re.match(r"^[a-z][a-z0-9-]*$", entity_id):
        schema_name = "agent.schema.json"
    # Skill: has harness (Draft-07)
    elif "harness" in top_keys:
        schema_name = "skill.schema.json"

if schema_name is None:
    print(f"[oma validate] cannot infer entity type for {entity_path}; "
          "supported: Deployment/Incident/Budget/Risk/Agent/Skill/Spec/ADR", file=sys.stderr)
    sys.exit(0)

schema_dir = repo_root / "schemas" / "ontology"
common_dir = repo_root / "schemas" / "common"
schema = json.loads((schema_dir / schema_name).read_text(encoding="utf-8"))

# Build ref store with ontology and common schemas
store = {}
for other in schema_dir.glob("*.schema.json"):
    content = json.loads(other.read_text(encoding="utf-8"))
    store[content["$id"]] = content
    store[other.name] = content
for common in common_dir.glob("*.schema.json"):
    content = json.loads(common.read_text(encoding="utf-8"))
    store[content["$id"]] = content
    store[common.name] = content

validator = validator_class(schema, resolver=RefResolver.from_schema(schema, store=store))
errs = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
if errs:
    print(f"[oma validate] {entity_path}: {len(errs)} schema violation(s)", file=sys.stderr)
    for e in errs:
        path = ".".join(str(p) for p in e.absolute_path) or "<root>"
        print(f"  - {path}: {e.message}", file=sys.stderr)
    sys.exit(1)
print(f"[oma validate] {entity_path}: schema OK")
PY

# ----- Runtime policy enforcement note --------------------------------------
# `oma validate` checks an ontology entity against its JSON Schema only.
# Runtime tool-call enforcement (deny mutating kubectl, secret writes, ...) is
# handled by the plugin's compiled PreToolUse hook — see the `policies:` block
# in each <plugin>.oma.yaml, compiled into hooks/harness-rules.json and enforced
# by hooks/enforce.py. There is no external policy engine and no opa dependency.
exit 0
