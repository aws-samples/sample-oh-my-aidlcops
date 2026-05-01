"""Audit event schema tests (Draft 2020-12)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker

SCHEMA = json.loads(
    (Path(__file__).resolve().parents[2] / "schemas" / "audit" / "event.schema.json").read_text(
        encoding="utf-8"
    )
)


def _validator() -> Draft202012Validator:
    # Explicit format-checker so ``format: date-time`` is enforced. Without it,
    # Draft202012Validator treats ``format`` as annotation-only.
    return Draft202012Validator(SCHEMA, format_checker=FormatChecker())


APPROVE_OK = {
    "timestamp": "2026-04-30T12:00:00Z",
    "actor": {"id": "alice@example.com", "role": "tech-lead"},
    "action": "approve",
    "target": {"entity_type": "Deployment", "entity_id": "vllm-llama3-70b"},
    "phase": "construction",
    "reason": "Rollback plan signed off.",
    "compliance": {"nist_ai_rmf": "GOVERN.1.1"},
}

BUDGET_BREACH_OK = {
    "timestamp": "2026-04-30T12:05:00Z",
    "actor": {"id": "cost-governance-skill"},
    "action": "budget-breach",
    "target": {"entity_type": "Budget", "entity_id": "autopilot-deploy-monthly"},
    "phase": "operations",
    "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
    "span_id": "00f067aa0ba902b7",
}

POLICY_DENY_OK = {
    "timestamp": "2026-04-30T12:10:00Z",
    "actor": {"id": "opa-guard"},
    "action": "policy-deny",
    "target": {"entity_type": "Risk", "entity_id": "prompt-injection-vllm"},
    "phase": "construction",
    "compliance": {"owasp_llm": "LLM01", "evidence_uri": "https://example.com/scan/123"},
}


@pytest.mark.parametrize(
    "payload",
    [APPROVE_OK, BUDGET_BREACH_OK, POLICY_DENY_OK],
    ids=["approve", "budget-breach", "policy-deny"],
)
def test_positive(payload):
    errs = list(_validator().iter_errors(payload))
    assert errs == [], [e.message for e in errs]


@pytest.mark.parametrize(
    "payload, expected_match",
    [
        # Missing required field
        ({"actor": {"id": "a"}, "action": "approve",
          "target": {"entity_type": "Deployment", "entity_id": "x"},
          "phase": "operations"}, "timestamp"),
        # Malformed timestamp rejected by the explicit ISO 8601 pattern.
        ({"timestamp": "not-a-date", "actor": {"id": "a"}, "action": "approve",
          "target": {"entity_type": "Deployment", "entity_id": "x"},
          "phase": "operations"}, "pattern"),
        # Unknown action
        ({"timestamp": "2026-04-30T12:00:00Z", "actor": {"id": "a"},
          "action": "acknowledge",
          "target": {"entity_type": "Deployment", "entity_id": "x"},
          "phase": "operations"}, "acknowledge"),
        # Unknown entity_type
        ({"timestamp": "2026-04-30T12:00:00Z", "actor": {"id": "a"},
          "action": "deploy",
          "target": {"entity_type": "Workflow", "entity_id": "x"},
          "phase": "operations"}, "Workflow"),
        # Malformed NIST subcategory
        ({"timestamp": "2026-04-30T12:00:00Z", "actor": {"id": "a"},
          "action": "approve",
          "target": {"entity_type": "Deployment", "entity_id": "x"},
          "phase": "construction",
          "compliance": {"nist_ai_rmf": "GOVERN-1-1"}}, "GOVERN-1-1"),
    ],
    ids=["missing-timestamp", "bad-date", "unknown-action", "unknown-entity", "bad-nist"],
)
def test_negative(payload, expected_match):
    errs = list(_validator().iter_errors(payload))
    assert errs, f"expected schema violations for {expected_match}"
