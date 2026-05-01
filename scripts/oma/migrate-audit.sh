#!/usr/bin/env bash
# scripts/oma/migrate-audit.sh — best-effort one-shot converter from the
# legacy aidlc-docs/audit.md Markdown append log to .omao/audit.jsonl.
#
# The legacy pattern was:
#   echo "[$(date -Iseconds)] free-form human message" >> aidlc-docs/audit.md
#
# We cannot infer actor/action/entity from those lines, so each Markdown
# line is backfilled as action=gate-pass with actor=legacy-markdown-appender.
# Operators should grep for entity_id==legacy-md to review backfilled
# records.

set -euo pipefail

SRC="${1:-aidlc-docs/audit.md}"
DEST="${2:-.omao/audit.jsonl}"

if [[ ! -f "$SRC" ]]; then
    echo "[migrate-audit] source $SRC not found — nothing to do"
    exit 0
fi

mkdir -p "$(dirname "$DEST")"

python3 - "$SRC" "$DEST" <<'PY'
import json, re, sys
from datetime import datetime, timezone
from pathlib import Path

src = Path(sys.argv[1])
dest = Path(sys.argv[2])
TS_RE = re.compile(r"^\[([0-9T:+.Z-]{10,})\]\s*(.*)$")

added = 0
with dest.open("a", encoding="utf-8") as out:
    for raw in src.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        m = TS_RE.match(raw)
        if m:
            ts, rest = m.group(1), m.group(2)
        else:
            ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            rest = raw
        event = {
            "timestamp": ts,
            "actor": {"id": "legacy-markdown-appender"},
            "action": "gate-pass",
            "target": {"entity_type": "Skill", "entity_id": "legacy-md"},
            "phase": "operations",
            "reason": rest[:1800],
        }
        out.write(json.dumps(event, ensure_ascii=False, sort_keys=True))
        out.write("\n")
        added += 1
print(f"[migrate-audit] appended {added} legacy lines to {dest}")
PY
