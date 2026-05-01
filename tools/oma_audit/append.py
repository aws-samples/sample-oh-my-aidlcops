"""Append a single validated audit event to ``.omao/audit.jsonl``.

Usage (Python):

    from tools.oma_audit import append_audit_event
    append_audit_event({
        "timestamp": "2026-04-30T12:00:00Z",
        "actor": {"id": "alice@example.com", "role": "tech-lead"},
        "action": "approve",
        "target": {"entity_type": "Deployment", "entity_id": "vllm-llama3-70b"},
        "phase": "construction",
        "reason": "Rollback plan validated.",
    })

Usage (shell, equivalent to the Markdown pattern being deprecated):

    python3 -m tools.oma_audit.append \
        --actor alice@example.com --role tech-lead \
        --action approve --entity-type Deployment --entity-id vllm-llama3-70b \
        --phase construction --reason "Rollback plan validated."

The helper validates every record against ``schemas/audit/event.schema.json``
before appending, so malformed events never reach disk. It is append-only:
concurrent callers race at the filesystem level but each line lands whole
because ``open(..., 'a')`` is atomic for <4 KiB writes on POSIX.
"""

from __future__ import annotations

import argparse
import json
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

warnings.filterwarnings(
    "ignore",
    category=DeprecationWarning,
    module=r"jsonschema(\..*)?",
)

from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
AUDIT_SCHEMA_PATH = REPO_ROOT / "schemas" / "audit" / "event.schema.json"
DEFAULT_AUDIT_LOG = Path(".omao") / "audit.jsonl"


class AuditValidationError(ValueError):
    """Raised when an audit event does not conform to event.schema.json."""


def _load_validator() -> Draft202012Validator:
    schema = json.loads(AUDIT_SCHEMA_PATH.read_text(encoding="utf-8"))
    return Draft202012Validator(schema, format_checker=FormatChecker())


def _iter_errors(event: dict[str, Any]) -> Iterable[str]:
    for err in _load_validator().iter_errors(event):
        path = ".".join(str(p) for p in err.absolute_path) or "<root>"
        yield f"  - {path}: {err.message}"


def append_audit_event(
    event: dict[str, Any],
    *,
    target_path: Path | None = None,
    workdir: Path | None = None,
) -> Path:
    """Validate and append an audit event.

    Returns the path of the file written to.
    Raises :class:`AuditValidationError` if the event fails schema validation.
    """
    errors = list(_iter_errors(event))
    if errors:
        raise AuditValidationError(
            "audit event failed schema validation:\n" + "\n".join(errors)
        )

    if target_path is None:
        base = workdir if workdir is not None else Path.cwd()
        target_path = base / DEFAULT_AUDIT_LOG

    target_path.parent.mkdir(parents=True, exist_ok=True)
    with target_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(event, ensure_ascii=False, sort_keys=True))
        fh.write("\n")
    return target_path


def _build_event_from_cli(ns: argparse.Namespace) -> dict[str, Any]:
    ts = ns.timestamp or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    event: dict[str, Any] = {
        "timestamp": ts,
        "actor": {"id": ns.actor},
        "action": ns.action,
        "target": {"entity_type": ns.entity_type, "entity_id": ns.entity_id},
        "phase": ns.phase,
    }
    if ns.role:
        event["actor"]["role"] = ns.role
    if ns.reason:
        event["reason"] = ns.reason
    if ns.nist_ai_rmf or ns.owasp_llm or ns.evidence_uri:
        compliance: dict[str, Any] = {}
        if ns.nist_ai_rmf:
            compliance["nist_ai_rmf"] = ns.nist_ai_rmf
        if ns.owasp_llm:
            compliance["owasp_llm"] = ns.owasp_llm
        if ns.evidence_uri:
            compliance["evidence_uri"] = ns.evidence_uri
        event["compliance"] = compliance
    if ns.trace_id:
        event["trace_id"] = ns.trace_id
    if ns.span_id:
        event["span_id"] = ns.span_id
    return event


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--actor", required=True)
    parser.add_argument("--role")
    parser.add_argument("--action", required=True)
    parser.add_argument("--entity-type", required=True, dest="entity_type")
    parser.add_argument("--entity-id", required=True, dest="entity_id")
    parser.add_argument("--phase", required=True,
                        choices=["inception", "construction", "operations"])
    parser.add_argument("--reason")
    parser.add_argument("--timestamp", help="Defaults to now in UTC ISO 8601.")
    parser.add_argument("--nist-ai-rmf", dest="nist_ai_rmf")
    parser.add_argument("--owasp-llm", dest="owasp_llm")
    parser.add_argument("--evidence-uri", dest="evidence_uri")
    parser.add_argument("--trace-id", dest="trace_id")
    parser.add_argument("--span-id", dest="span_id")
    parser.add_argument("--audit-file", dest="audit_file",
                        help="Override output path (default: .omao/audit.jsonl).")
    ns = parser.parse_args(argv)

    event = _build_event_from_cli(ns)
    target = Path(ns.audit_file) if ns.audit_file else None
    try:
        written = append_audit_event(event, target_path=target)
    except AuditValidationError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    print(f"audit event appended to {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
