"""Test CLI writer migration from echo >> audit.md to python -m tools.oma_audit.append."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads(
    (REPO_ROOT / "schemas" / "audit" / "event.schema.json").read_text(encoding="utf-8")
)


def _validator() -> Draft202012Validator:
    return Draft202012Validator(SCHEMA, format_checker=FormatChecker())


def test_component_design_migration_command(tmp_path):
    """Verify the exact command migrated into component-design SKILL.md writes valid JSONL."""
    audit_file = tmp_path / "audit.jsonl"

    # Replicate the exact command from SKILL.md (using literal values instead of $USER)
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "tools.oma_audit.append",
            "--actor",
            "test-user",
            "--role",
            "skill-component-design",
            "--action",
            "gate-pass",
            "--entity-type",
            "Skill",
            "--entity-id",
            "component-design",
            "--phase",
            "construction",
            "--reason",
            "design.md submitted for review",
            "--audit-file",
            str(audit_file),
        ],
        cwd=str(REPO_ROOT),
        env={"PYTHONPATH": str(REPO_ROOT)},
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, f"CLI failed: {result.stderr}"
    assert audit_file.exists(), "audit file was not created"

    # Parse the written line and validate against schema
    lines = audit_file.read_text(encoding="utf-8").strip().split("\n")
    assert len(lines) == 1, "expected exactly one JSONL record"

    event = json.loads(lines[0])
    errors = list(_validator().iter_errors(event))
    assert errors == [], [e.message for e in errors]

    # Verify the expected fields
    assert event["actor"]["id"] == "test-user"
    assert event["actor"]["role"] == "skill-component-design"
    assert event["action"] == "gate-pass"
    assert event["target"]["entity_type"] == "Skill"
    assert event["target"]["entity_id"] == "component-design"
    assert event["phase"] == "construction"
    assert event["reason"] == "design.md submitted for review"


def test_bad_action_rejected(tmp_path):
    """Verify that invalid action values cause CLI to exit 2."""
    audit_file = tmp_path / "audit.jsonl"

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "tools.oma_audit.append",
            "--actor",
            "test-user",
            "--action",
            "invalid-action-name",
            "--entity-type",
            "Skill",
            "--entity-id",
            "component-design",
            "--phase",
            "construction",
            "--audit-file",
            str(audit_file),
        ],
        cwd=str(REPO_ROOT),
        env={"PYTHONPATH": str(REPO_ROOT)},
        capture_output=True,
        text=True,
    )

    assert result.returncode == 2, "expected exit code 2 for validation failure"
    assert not audit_file.exists(), "audit file should not be created on validation failure"
    assert "schema validation" in result.stderr.lower(), "expected schema error message"
