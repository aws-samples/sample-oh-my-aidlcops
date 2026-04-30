#!/usr/bin/env bash
# scripts/oma/_seed.sh — helper used by setup.sh to render ontology seed files.
# Sourced, not executed. Requires scripts/lib/log.sh already loaded.
#
# Public functions:
#   seed_render <tmpl-file> <output-file> <key=val>...
#   seed_validate_ontology <project-dir>

if [ "${__OMA_SEED_LOADED:-0}" = 1 ]; then return 0; fi
__OMA_SEED_LOADED=1

seed_render() {
    tmpl="$1"; out="$2"; shift 2
    [ -f "$tmpl" ] || die "template missing: $tmpl"
    mkdir -p "$(dirname "$out")"
    contents="$(cat "$tmpl")"
    for pair in "$@"; do
        key="${pair%%=*}"; val="${pair#*=}"
        # Escape sed replacement special chars: &, |, /
        esc="$(printf '%s' "$val" | sed -e 's/[&|\\]/\\&/g')"
        contents="$(printf '%s' "$contents" | sed "s|{{${key}}}|${esc}|g")"
    done
    printf '%s\n' "$contents" > "$out"
}

seed_validate_ontology() {
    project_dir="${1:-$PWD}"
    repo_root="${OMA_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    schema_dir="$repo_root/schemas/ontology"
    [ -d "$schema_dir" ] || die "schemas/ontology missing in repo"
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 missing — skipping ontology schema validation"
        return 0
    fi
    python3 - "$project_dir" "$schema_dir" <<'PY'
import json, sys
from pathlib import Path
try:
    from jsonschema import Draft7Validator
except ImportError:
    print("[seed] python jsonschema missing; skip", file=sys.stderr)
    sys.exit(0)

project = Path(sys.argv[1])
schemas = Path(sys.argv[2])
targets = {
    "budgets": schemas / "budget.schema.json",
    "deployments": schemas / "deployment.schema.json",
    "risks": schemas / "risk.schema.json",
    "incidents": schemas / "incident.schema.json",
}
failed = 0
for name, schema_path in targets.items():
    root = project / ".omao" / "ontology" / name
    if not root.exists():
        continue
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validator = Draft7Validator(schema)
    for path in root.glob("*.json"):
        doc = json.loads(path.read_text(encoding="utf-8"))
        errors = list(validator.iter_errors(doc))
        if errors:
            failed += 1
            for e in errors:
                print(f"[seed-invalid] {path}: {e.message}", file=sys.stderr)
sys.exit(1 if failed else 0)
PY
}
