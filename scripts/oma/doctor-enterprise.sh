#!/usr/bin/env bash
# scripts/oma/doctor-enterprise.sh — 8 enterprise-readiness probes.
#
# Invoked via `oma doctor --enterprise`. Every probe is independent;
# an exit code of 0 means all probes passed, 1 means at least one
# blocking finding, 2 means the doctor itself could not run (missing
# python3 / jsonschema).

set -euo pipefail

OMA_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$OMA_ROOT"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[doctor:enterprise] python3 not found" >&2
    exit 2
fi

python3 - "$OMA_ROOT" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []
warnings = []

# ---------- Probe #1: ontology fixtures validate under Draft 2020-12 -------
try:
    from jsonschema import Draft202012Validator
except Exception as exc:
    print(f"[doctor:enterprise] jsonschema import failed: {exc}", file=sys.stderr)
    sys.exit(2)

for name in ("spec.schema.json", "adr.schema.json"):
    path = root / "schemas" / "ontology" / name
    if not path.exists():
        failures.append(f"probe-1 ontology-2020-12: {path} missing")
        continue
    try:
        Draft202012Validator.check_schema(json.loads(path.read_text(encoding="utf-8")))
    except Exception as exc:
        failures.append(f"probe-1 ontology-2020-12: {name}: {exc}")

# ---------- Probe #2: Deployment artifact digest format --------------------
DIGEST_RE = re.compile(r"^sha256:[a-f0-9]{64}$")
deploy_dir = root / ".omao" / "ontology" / "deployments"
if deploy_dir.is_dir():
    for dep_file in deploy_dir.glob("*.json"):
        try:
            doc = json.loads(dep_file.read_text(encoding="utf-8"))
        except Exception as exc:
            failures.append(f"probe-2 slsa-digest: {dep_file}: {exc}")
            continue
        art = doc.get("artifact")
        if isinstance(art, dict):
            if not DIGEST_RE.match(art.get("digest", "")):
                failures.append(
                    f"probe-2 slsa-digest: {dep_file}: artifact.digest missing or malformed"
                )

# ---------- Probe #3: Risk has OWASP or NIST classification ---------------
risk_dir = root / ".omao" / "ontology" / "risks"
if risk_dir.is_dir():
    for risk_file in risk_dir.glob("*.json"):
        try:
            doc = json.loads(risk_file.read_text(encoding="utf-8"))
        except Exception as exc:
            failures.append(f"probe-3 risk-classification: {risk_file}: {exc}")
            continue
        if not (doc.get("owasp_llm_top10_id") or doc.get("nist_ai_rmf_subcategory")):
            failures.append(
                f"probe-3 risk-classification: {risk_file} (id={doc.get('id','?')}): "
                "requires owasp_llm_top10_id or nist_ai_rmf_subcategory"
            )

# ---------- Probe #4: audit.jsonl lines validate --------------------------
audit_log = root / ".omao" / "audit.jsonl"
event_schema_path = root / "schemas" / "audit" / "event.schema.json"
if audit_log.exists() and event_schema_path.exists():
    schema = json.loads(event_schema_path.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)
    for i, raw in enumerate(audit_log.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw.strip():
            continue
        try:
            evt = json.loads(raw)
        except Exception as exc:
            failures.append(f"probe-4 audit-jsonl: line {i}: not JSON: {exc}")
            continue
        errs = list(validator.iter_errors(evt))
        if errs:
            failures.append(
                f"probe-4 audit-jsonl: line {i}: {len(errs)} violation(s); first: {errs[0].message}"
            )

# ---------- Probe #5: every *.oma.yaml is version 2 ------------------------
import yaml
for dsl in (root / "plugins").glob("*/*.oma.yaml"):
    doc = yaml.safe_load(dsl.read_text(encoding="utf-8")) or {}
    if doc.get("version") != 2:
        warnings.append(
            f"probe-5 dsl-version: {dsl.relative_to(root)}: version={doc.get('version')} "
            "(warning only; upgrade to 2 before --strict-enterprise)"
        )

# ---------- Probe #6: policies[].rego_ref all exist -----------------------
for dsl in (root / "plugins").glob("*/*.oma.yaml"):
    doc = yaml.safe_load(dsl.read_text(encoding="utf-8")) or {}
    for policy in doc.get("policies") or []:
        ref = policy.get("rego_ref")
        if ref and not (root / ref).exists():
            failures.append(
                f"probe-6 policies-rego: {dsl.relative_to(root)}: policy {policy.get('id')!r} "
                f"rego_ref {ref!r} missing"
            )

# ---------- Probe #7: plugins without *.oma.yaml (warn only) --------------
for plugin_dir in (root / "plugins").iterdir():
    if not plugin_dir.is_dir():
        continue
    if not list(plugin_dir.glob("*.oma.yaml")):
        warnings.append(
            f"probe-7 plugin-dsl: {plugin_dir.relative_to(root)}: no *.oma.yaml "
            "(still uses raw plugin.json)"
        )

# ---------- Probe #8: MCP pinned versions ---------------------------------
PIN = re.compile(r"==\d+\.\d+\.\d+")
for dsl in (root / "plugins").glob("*/*.oma.yaml"):
    doc = yaml.safe_load(dsl.read_text(encoding="utf-8")) or {}
    for name, server in (doc.get("mcp") or {}).items():
        args = server.get("args") or []
        if not any(PIN.search(a) for a in args):
            failures.append(
                f"probe-8 mcp-pinned: {dsl.relative_to(root)}: mcp {name!r} "
                "has no pinned version (expected ==X.Y.Z in args)"
            )

# ---------- Report ---------------------------------------------------------
for w in warnings:
    print(f"WARN  {w}")
for f in failures:
    print(f"FAIL  {f}", file=sys.stderr)

if failures:
    print(f"\n[doctor:enterprise] {len(failures)} blocking, {len(warnings)} warnings", file=sys.stderr)
    sys.exit(1)
print(f"[doctor:enterprise] 8 probes OK ({len(warnings)} warnings)")
PY
