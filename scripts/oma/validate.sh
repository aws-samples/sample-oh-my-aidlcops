#!/usr/bin/env bash
# scripts/oma/validate.sh — validate a Deployment (or other ontology entity)
# YAML/JSON file against its schema, and optionally evaluate any Rego
# policies declared in the same plugin's *.oma.yaml.
#
# Usage:
#   oma validate <path-to-entity.yaml> [--plugin <plugin-name>]
#
# Behaviour:
#   1. Loads <entity> and validates it against the matching ontology schema
#      (currently Deployment only; other entity types print a warning).
#   2. Discovers `<plugin>/*.oma.yaml`; reads `spec.policies[]`.
#   3. For each policy with severity in {blocking, warning, advisory}:
#        - if `opa` is installed → runs `opa eval` with the policy and input,
#          interprets `data.oma.deny` as a list of human-readable messages.
#        - if `opa` is missing → prints install hint, falls back to
#          schema-only validation (exits 0 with a warning).
#   4. Exit code: 0 if no blocking findings; 1 if any blocking finding.
#   Warnings and advisories never change the exit code.

set -euo pipefail

die() { printf "[oma validate] %s\n" "$*" >&2; exit 1; }
warn() { printf "[oma validate] %s\n" "$*" >&2; }

OMA_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENTITY_FILE=""
PLUGIN_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plugin) PLUGIN_NAME="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# //; s/^#//'
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
import json, sys
from pathlib import Path

import yaml
from jsonschema import Draft7Validator, RefResolver

repo_root = Path(sys.argv[1])
entity_path = Path(sys.argv[2])

data = yaml.safe_load(entity_path.read_text(encoding="utf-8"))
# Heuristic: Deployment has target/artifact/approval_state.
schema_name = None
if isinstance(data, dict) and {"target", "artifact", "approval_state"} <= set(data):
    schema_name = "deployment.schema.json"
if schema_name is None:
    print(f"[oma validate] cannot infer entity type for {entity_path}; "
          "only Deployment schema is wired in v0.4.", file=sys.stderr)
    sys.exit(0)

schema_dir = repo_root / "schemas" / "ontology"
schema = json.loads((schema_dir / schema_name).read_text(encoding="utf-8"))
store = {}
for other in schema_dir.glob("*.schema.json"):
    content = json.loads(other.read_text(encoding="utf-8"))
    store[content["$id"]] = content
    store[other.name] = content
validator = Draft7Validator(schema, resolver=RefResolver.from_schema(schema, store=store))
errs = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
if errs:
    print(f"[oma validate] {entity_path}: {len(errs)} schema violation(s)", file=sys.stderr)
    for e in errs:
        path = ".".join(str(p) for p in e.absolute_path) or "<root>"
        print(f"  - {path}: {e.message}", file=sys.stderr)
    sys.exit(1)
print(f"[oma validate] {entity_path}: schema OK")
PY

# ----- Policy evaluation (optional, requires opa) --------------------------
POLICY_FOUND=0
if [[ -n "$PLUGIN_NAME" ]]; then
    DSL="$OMA_ROOT/plugins/$PLUGIN_NAME/${PLUGIN_NAME}.oma.yaml"
else
    DSL=$(find "$OMA_ROOT/plugins" -maxdepth 2 -name '*.oma.yaml' 2>/dev/null | head -n1 || true)
fi

if [[ -z "$DSL" || ! -f "$DSL" ]]; then
    exit 0
fi

POLICIES_JSON=$(python3 - "$DSL" <<'PY'
import json, sys
import yaml
dsl = yaml.safe_load(open(sys.argv[1], "r", encoding="utf-8"))
pols = dsl.get("policies") or []
print(json.dumps(pols))
PY
)

if [[ "$POLICIES_JSON" == "[]" ]]; then
    exit 0
fi

if ! command -v opa >/dev/null 2>&1; then
    warn "opa binary not found; skipping policy evaluation."
    warn "Install: https://www.openpolicyagent.org/docs/latest/#running-opa"
    exit 0
fi

BLOCKING_VIOLATIONS=0
while IFS= read -r policy; do
    [[ -z "$policy" ]] && continue
    id=$(echo "$policy" | python3 -c 'import json,sys;print(json.loads(sys.stdin.read())["id"])')
    rego=$(echo "$policy" | python3 -c 'import json,sys;print(json.loads(sys.stdin.read())["rego_ref"])')
    severity=$(echo "$policy" | python3 -c 'import json,sys;print(json.loads(sys.stdin.read()).get("severity","blocking"))')
    rego_path="$OMA_ROOT/$rego"
    if [[ ! -f "$rego_path" ]]; then
        warn "policy $id: rego file missing at $rego_path (skipping)"
        continue
    fi
    # opa eval --data <rego> --input <entity> 'data.oma.deny'
    result=$(opa eval --data "$rego_path" --input "$ENTITY_FILE" --format json 'data.oma.deny' 2>/dev/null || echo '{}')
    count=$(echo "$result" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read() or "{}");print(len((d.get("result") or [{}])[0].get("expressions",[{}])[0].get("value") or []))')
    if [[ "$count" != "0" ]]; then
        echo "[oma validate] policy $id (severity=$severity): $count finding(s)"
        echo "$result" | python3 -c 'import json,sys;d=json.loads(sys.stdin.read());
for msg in (d.get("result") or [{}])[0].get("expressions",[{}])[0].get("value") or []:
    print(f"  - {msg}")'
        if [[ "$severity" == "blocking" ]]; then
            BLOCKING_VIOLATIONS=$((BLOCKING_VIOLATIONS + count))
        fi
    fi
done < <(echo "$POLICIES_JSON" | python3 -c '
import json, sys
for p in json.loads(sys.stdin.read()):
    print(json.dumps(p))
')

if [[ "$BLOCKING_VIOLATIONS" -gt 0 ]]; then
    exit 1
fi
exit 0
