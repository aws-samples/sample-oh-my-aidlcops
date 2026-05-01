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


# ---------------------------------------------------------------------------
# Enterprise optional-field fixtures (v0.3a PR 3).
# These extend the minimal positive payloads with every enterprise field so
# we prove additive compatibility: the schemas keep passing even when a
# consumer populates the new enterprise surface.
# ---------------------------------------------------------------------------

AGENT_ENTERPRISE = {
    **AGENT_OK,
    "mcp_uri": "mcp://awslabs.eks-mcp-server",
    "model_tier": "opus",
}

SKILL_ENTERPRISE = {
    **SKILL_OK,
    "sla_tier": "critical",
}

DEPLOYMENT_ENTERPRISE = {
    **DEPLOYMENT_OK,
    "approval_chain": [
        {
            "approver": "alice@example.com",
            "approved_at": "2026-04-30T12:00:00Z",
            "reason": "Rollback plan validated.",
            "role": "tech-lead",
        }
    ],
    "risk_exceptions": ["legacy-oracle-migration"],
}

INCIDENT_ENTERPRISE = {
    **INCIDENT_OK,
    "approval_chain": [
        {
            "approver": "oncall-team",
            "approved_at": "2026-04-30T12:05:00Z",
            "reason": "Runbook override acknowledged.",
        }
    ],
    "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
    "span_id": "00f067aa0ba902b7",
}

BUDGET_ENTERPRISE = {
    **BUDGET_OK,
    "cost_center_owner": "finops@example.com",
    "approval_gate": "finops-director",
    "exception_expires_at": "2026-06-01T00:00:00Z",
}

RISK_ENTERPRISE = {
    **RISK_OK,
    "owasp_llm_top10_id": "LLM01",
    "nist_ai_rmf_subcategory": "GOVERN.1.1",
    "compliance_refs": [
        {"framework": "iso-42001", "control_id": "8.2"},
        {"framework": "nist-800-53", "control_id": "SI-12"},
    ],
    "deployment_refs": ["vllm-llama3-70b"],
}


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        ("agent.schema.json", AGENT_ENTERPRISE),
        ("skill.schema.json", SKILL_ENTERPRISE),
        ("deployment.schema.json", DEPLOYMENT_ENTERPRISE),
        ("incident.schema.json", INCIDENT_ENTERPRISE),
        ("budget.schema.json", BUDGET_ENTERPRISE),
        ("risk.schema.json", RISK_ENTERPRISE),
    ],
)
def test_enterprise_fields_accepted(schema_name, payload):
    validator = _validator(schema_name)
    errors = list(validator.iter_errors(payload))
    assert errors == [], [e.message for e in errors]


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        # model_tier enum violation
        ("agent.schema.json", {**AGENT_OK, "model_tier": "gpt-5"}),
        # sla_tier enum violation
        ("skill.schema.json", {**SKILL_OK, "sla_tier": "platinum"}),
        # approval_chain missing required approver field
        (
            "deployment.schema.json",
            {
                **DEPLOYMENT_OK,
                "approval_chain": [
                    {"approved_at": "2026-04-30T12:00:00Z", "reason": "r"}
                ],
            },
        ),
        # trace_id bad pattern
        ("incident.schema.json", {**INCIDENT_OK, "trace_id": "not-hex"}),
        # approval_gate enum violation
        ("budget.schema.json", {**BUDGET_OK, "approval_gate": "board"}),
        # owasp_llm_top10_id enum violation
        ("risk.schema.json", {**RISK_OK, "owasp_llm_top10_id": "LLM99"}),
        # nist_ai_rmf_subcategory pattern violation
        ("risk.schema.json", {**RISK_OK, "nist_ai_rmf_subcategory": "GOVERN-1-1"}),
    ],
    ids=[
        "agent.model_tier",
        "skill.sla_tier",
        "deployment.approval_chain",
        "incident.trace_id",
        "budget.approval_gate",
        "risk.owasp_llm",
        "risk.nist_subcat",
    ],
)
def test_enterprise_fields_negative(schema_name, payload):
    validator = _validator(schema_name)
    errors = list(validator.iter_errors(payload))
    assert errors, "expected schema violations but payload validated"
