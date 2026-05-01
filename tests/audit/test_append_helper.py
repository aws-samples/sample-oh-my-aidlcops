"""tools.oma_audit.append integration tests."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.oma_audit import AuditValidationError, append_audit_event


def test_appends_validated_event(tmp_path):
    target = tmp_path / ".omao" / "audit.jsonl"
    event = {
        "timestamp": "2026-04-30T12:00:00Z",
        "actor": {"id": "alice@example.com", "role": "tech-lead"},
        "action": "approve",
        "target": {"entity_type": "Deployment", "entity_id": "vllm-llama3-70b"},
        "phase": "construction",
        "reason": "Rollback plan validated.",
    }
    append_audit_event(event, target_path=target)
    append_audit_event(event, target_path=target)

    lines = target.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 2
    for line in lines:
        parsed = json.loads(line)
        assert parsed["action"] == "approve"
        assert parsed["target"]["entity_id"] == "vllm-llama3-70b"


def test_rejects_missing_required_field(tmp_path):
    target = tmp_path / ".omao" / "audit.jsonl"
    bad = {
        "actor": {"id": "a"},
        "action": "approve",
        "target": {"entity_type": "Deployment", "entity_id": "x"},
        "phase": "operations",
    }
    with pytest.raises(AuditValidationError):
        append_audit_event(bad, target_path=target)
    assert not target.exists(), "file must not be created on validation failure"


def test_rejects_unknown_action(tmp_path):
    target = tmp_path / ".omao" / "audit.jsonl"
    bad = {
        "timestamp": "2026-04-30T12:00:00Z",
        "actor": {"id": "a"},
        "action": "acknowledge",
        "target": {"entity_type": "Deployment", "entity_id": "x"},
        "phase": "operations",
    }
    with pytest.raises(AuditValidationError):
        append_audit_event(bad, target_path=target)
