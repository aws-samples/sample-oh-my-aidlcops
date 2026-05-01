#!/usr/bin/env bash
# scripts/oma/enterprise-status.sh — summarise enterprise readiness.
#
# Runs `oma doctor --enterprise` under the hood, then layers the
# phased-adoption stage counters from
# docs/docs/enterprise-readiness.md on top so operators can see where
# they are on the rollout path at a glance.
#
# Output modes:
#   oma status --enterprise           pretty text (default, colour when TTY)
#   oma status --enterprise --json    machine-readable JSON to stdout,
#                                     also archived to .omao/status.json
#
# Exit codes:
#   0  enterprise gate passes and every stage currently achievable
#      (stages 1-6) shows green
#   1  at least one doctor probe fails or at least one mandatory stage
#      shows red
#   2  runtime error (python3 missing, CHANGELOG unreadable, ...)

set -euo pipefail

OMA_REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$OMA_REPO_ROOT"

FORMAT=pretty
while [ $# -gt 0 ]; do
    case "$1" in
        --json)       FORMAT=json; shift ;;
        --enterprise) shift ;;  # accepted for alias dispatch via `oma status --enterprise`
        -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "[enterprise-status] unknown flag: $1" >&2; exit 2 ;;
    esac
done

if ! command -v python3 >/dev/null 2>&1; then
    echo "[enterprise-status] python3 not found" >&2
    exit 2
fi

# Run the doctor and capture its output (both stdout and stderr).
DOCTOR_OUT="$(bash "$OMA_REPO_ROOT/scripts/oma/doctor-enterprise.sh" 2>&1 || true)"
DOCTOR_EXIT=$?

python3 - "$OMA_REPO_ROOT" "$DOCTOR_OUT" "$FORMAT" <<'PY'
import datetime, json, os, re, sys
from pathlib import Path

root = Path(sys.argv[1])
doctor_out = sys.argv[2]
fmt = sys.argv[3]

# ---------- Parse the doctor output ----------
probe_failures = []
probe_warnings = []
for line in doctor_out.splitlines():
    if line.startswith("FAIL  "):
        probe_failures.append(line[6:].rstrip())
    elif line.startswith("WARN  "):
        probe_warnings.append(line[6:].rstrip())

overall_ok = not probe_failures

# ---------- Phased-adoption stages ----------
# Mirrors docs/docs/enterprise-readiness.md "Phased adoption" table.
# Each stage is a heuristic check against current repo state.
stages = []

def stage(n, name, done, detail=""):
    stages.append({"stage": n, "name": name, "done": bool(done), "detail": detail})

# Stage 1: doctor --enterprise clean (no blocking failures).
stage(1, "doctor --enterprise clean", overall_ok,
      f"{len(probe_failures)} blocking, {len(probe_warnings)} warnings")

# Stage 2: every risk has OWASP or NIST classification (probe 3 would catch it).
risk_dir = root / ".omao" / "ontology" / "risks"
risks_total = 0
risks_missing = 0
if risk_dir.is_dir():
    for rf in risk_dir.glob("*.json"):
        risks_total += 1
        try:
            doc = json.loads(rf.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not (doc.get("owasp_llm_top10_id") or doc.get("nist_ai_rmf_subcategory")):
            risks_missing += 1
stage(2, "Every Risk classified under OWASP or NIST",
      risks_total == 0 or risks_missing == 0,
      f"{risks_total - risks_missing}/{risks_total} classified"
      if risks_total else "no Risk files on disk yet")

# Stage 3: every Deployment artifact uses the object form.
dep_dir = root / ".omao" / "ontology" / "deployments"
dep_total = 0
dep_object = 0
for dep_file in (dep_dir.glob("*.json") if dep_dir.is_dir() else []):
    dep_total += 1
    try:
        doc = json.loads(dep_file.read_text(encoding="utf-8"))
    except Exception:
        continue
    if isinstance(doc.get("artifact"), dict):
        dep_object += 1
stage(3, "Deployment.artifact migrated to object form",
      dep_total == 0 or dep_object == dep_total,
      f"{dep_object}/{dep_total} on object form"
      if dep_total else "no Deployment files on disk yet")

# Stage 4: audit.jsonl in use (file exists and is non-empty).
audit_log = root / ".omao" / "audit.jsonl"
audit_lines = 0
if audit_log.is_file():
    with audit_log.open("r", encoding="utf-8") as fh:
        audit_lines = sum(1 for line in fh if line.strip())
stage(4, ".omao/audit.jsonl actively written",
      audit_lines > 0,
      f"{audit_lines} event(s) recorded"
      if audit_lines else "append via python -m tools.oma_audit.append to start")

# Stage 5: strict-enterprise is enforced by some workflow (simple grep).
workflows = root / ".github" / "workflows"
strict_found = False
for wf in (workflows.glob("*.yml") if workflows.is_dir() else []):
    if "--strict-enterprise" in wf.read_text(encoding="utf-8"):
        strict_found = True
        break
stage(5, "compile --strict-enterprise runs in CI", strict_found,
      "add it to oma-foundation.yml or release.yml when ready")

# Stage 6: legacy audit.md removed.
legacy_audit = root / "aidlc-docs" / "audit.md"
stage(6, "Legacy aidlc-docs/audit.md removed",
      not legacy_audit.exists(),
      "still present" if legacy_audit.exists() else "clean")

completed = sum(1 for s in stages if s["done"])
completion_pct = round(100 * completed / len(stages)) if stages else 0

summary = {
    "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "overall_ok": overall_ok,
    "probe_failures": probe_failures,
    "probe_warnings": probe_warnings,
    "stages": stages,
    "completion_pct": completion_pct,
}

# Always archive to .omao/status.json for later diffing.
status_out = root / ".omao" / "status.json"
status_out.parent.mkdir(parents=True, exist_ok=True)
status_out.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

if fmt == "json":
    print(json.dumps(summary, indent=2))
    sys.exit(0 if overall_ok and completed == len(stages) else 1)

# Pretty text output.
use_color = sys.stdout.isatty() and os.environ.get("NO_COLOR") != "1"
def col(code, s):
    return f"\033[{code}m{s}\033[0m" if use_color else s

print(col("1", "[oma status] enterprise readiness"))
print(f"  overall: {col('32','PASS') if overall_ok else col('31','FAIL')}"
      f"  ({len(probe_failures)} blocking, {len(probe_warnings)} warnings)")
print(f"  phased adoption: {completed}/{len(stages)} ({completion_pct}%)")
for s in stages:
    mark = col("32", "✓") if s["done"] else col("31", "✗")
    print(f"    {mark} Stage {s['stage']}: {s['name']} — {s['detail']}")
if probe_failures:
    print()
    print(col("1", "Blocking probe findings:"))
    for f in probe_failures:
        print(f"  - {f}")
if probe_warnings:
    print()
    print(col("1", "Warnings:"))
    for w in probe_warnings:
        print(f"  - {w}")
print()
print(f"Archived to {status_out.relative_to(root)}")

sys.exit(0 if overall_ok and completed == len(stages) else 1)
PY
