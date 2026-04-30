"""Ontology schema validation tests.

One positive and one negative fixture per schema. Fixtures live inline
because they double as documentation of the minimal valid shape.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft7Validator, RefResolver

SCHEMA_DIR = Path(__file__).resolve().parents[2] / "schemas" / "ontology"


def _load(name: str) -> dict:
    with (SCHEMA_DIR / name).open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _validator(schema_name: str) -> Draft7Validator:
    schema = _load(schema_name)
    # Resolve cross-schema $ref (skill -> agent) by mapping $id -> local content.
    store = {}
    for other in SCHEMA_DIR.glob("*.schema.json"):
        content = json.loads(other.read_text(encoding="utf-8"))
        store[content["$id"]] = content
        store[other.name] = content  # allow relative "agent.schema.json" refs
    resolver = RefResolver.from_schema(schema, store=store)
    return Draft7Validator(schema, resolver=resolver)


AGENT_OK = {
    "id": "autopilot-deploy",
    "runtime": "claude-code",
    "tier": 0,
    "mcp": ["eks", "cloudwatch"],
    "ontology": {"produces": ["Deployment"], "consumes": ["Spec", "ADR"]},
}
AGENT_BAD = {"id": "Invalid_Id", "runtime": "unknown"}

SKILL_OK = {
    "id": "autopilot",
    "harness": "both",
    "triggers": ["autopilot"],
    "ontology": {"produces": ["Deployment"]},
}
SKILL_BAD = {"id": "ok", "harness": "vscode"}

DEPLOYMENT_OK = {
    "id": "vllm-llama3-70b",
    "target": "eks",
    "artifact": "public.ecr.aws/example/vllm:0.18.2",
    "approval_state": "proposed",
    "blast_radius": "single-cluster",
}
DEPLOYMENT_BAD = {"id": "x", "target": "mainframe", "artifact": "", "approval_state": "queued"}

INCIDENT_OK = {
    "id": "inc-2026-04-30-001",
    "severity": "sev-2",
    "alarm_source": "CloudWatch:HighGpuUtilization",
    "approval_state": "proposed",
}
INCIDENT_BAD = {"id": "inc!", "severity": "catastrophic", "alarm_source": "", "approval_state": "?"}

BUDGET_OK = {
    "id": "autopilot-deploy-monthly",
    "scope": "agent",
    "scope_ref": "autopilot-deploy",
    "limit_usd": 250.0,
    "period": "monthly",
    "rule_expression": "spend_usd > limit_usd * 0.8",
    "action_on_breach": "notify",
}
BUDGET_BAD = {
    "id": "b",
    "scope": "world",
    "limit_usd": -10,
    "period": "fortnightly",
    "rule_expression": "",
    "action_on_breach": "panic",
}

RISK_OK = {
    "id": "legacy-oracle-migration",
    "category": "replatform",
    "likelihood": "medium",
    "impact": "major",
    "mitigation": "Two-phase cutover with shadow reads for 2 weeks.",
    "gate_ref": "gate-data-migration",
}
RISK_BAD = {"id": "x", "category": "unknown-bucket", "likelihood": "never", "impact": "tiny"}


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        ("agent.schema.json", AGENT_OK),
        ("skill.schema.json", SKILL_OK),
        ("deployment.schema.json", DEPLOYMENT_OK),
        ("incident.schema.json", INCIDENT_OK),
        ("budget.schema.json", BUDGET_OK),
        ("risk.schema.json", RISK_OK),
    ],
)
def test_positive(schema_name, payload):
    validator = _validator(schema_name)
    errors = list(validator.iter_errors(payload))
    assert errors == [], [e.message for e in errors]


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        ("agent.schema.json", AGENT_BAD),
        ("skill.schema.json", SKILL_BAD),
        ("deployment.schema.json", DEPLOYMENT_BAD),
        ("incident.schema.json", INCIDENT_BAD),
        ("budget.schema.json", BUDGET_BAD),
        ("risk.schema.json", RISK_BAD),
    ],
)
def test_negative(schema_name, payload):
    validator = _validator(schema_name)
    errors = list(validator.iter_errors(payload))
    assert errors, "expected schema violations but payload validated"
