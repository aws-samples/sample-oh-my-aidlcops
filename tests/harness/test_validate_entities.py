"""Multi-entity validation tests for scripts/oma/validate.sh.

Covers all 8 ontology entity types: Deployment, Incident, Budget, Risk,
Agent, Skill, Spec, ADR. Each entity gets a positive case (valid minimal
fixture) and a negative case (schema violation).
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
VALIDATE_SH = REPO_ROOT / "scripts" / "oma" / "validate.sh"


def _run(args: list[str], cwd: Path | None = None, env: dict[str, str] | None = None):
    """Run validate.sh with the current python in PATH so jsonschema/pyyaml are importable."""
    import sys as _sys
    py_dir = str(Path(_sys.executable).parent)
    merged_env = {**os.environ, **(env or {})}
    merged_env["PATH"] = py_dir + os.pathsep + merged_env.get("PATH", "")
    return subprocess.run(
        ["bash", str(VALIDATE_SH), *args],
        capture_output=True,
        text=True,
        cwd=str(cwd or REPO_ROOT),
        env=merged_env,
    )


def _write_yaml(tmp_path: Path, filename: str, doc: dict) -> Path:
    out = tmp_path / filename
    out.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
    return out


# ========== Deployment ==========


def test_deployment_valid(tmp_path):
    doc = {
        "id": "vllm-llama3-70b",
        "target": "eks",
        "artifact": "public.ecr.aws/example/vllm:0.18.2",
        "approval_state": "proposed",
    }
    path = _write_yaml(tmp_path, "deployment.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_deployment_invalid_target(tmp_path):
    doc = {
        "id": "test-deploy",
        "target": "mainframe",  # not in enum
        "artifact": "foo",
        "approval_state": "proposed",
    }
    path = _write_yaml(tmp_path, "deployment.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Incident ==========


def test_incident_valid(tmp_path):
    doc = {
        "id": "inc-2024-001",
        "severity": "sev-2",
        "alarm_source": "CloudWatch:CPUUtilization",
        "approval_state": "draft",
    }
    path = _write_yaml(tmp_path, "incident.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_incident_invalid_severity(tmp_path):
    doc = {
        "id": "inc-bad",
        "severity": "sev-99",  # not in enum
        "alarm_source": "test",
        "approval_state": "draft",
    }
    path = _write_yaml(tmp_path, "incident.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Budget ==========


def test_budget_valid(tmp_path):
    doc = {
        "id": "budget-dev-team",
        "scope": "account",
        "limit_usd": 1000.0,
        "period": "monthly",
        "rule_expression": "spend_usd > limit_usd * 0.9",
        "action_on_breach": "notify",
    }
    path = _write_yaml(tmp_path, "budget.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_budget_invalid_period(tmp_path):
    doc = {
        "id": "budget-bad",
        "scope": "account",
        "limit_usd": 500.0,
        "period": "annually",  # not in enum
        "rule_expression": "true",
        "action_on_breach": "notify",
    }
    path = _write_yaml(tmp_path, "budget.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Risk ==========


def test_risk_valid(tmp_path):
    doc = {
        "id": "risk-data-loss",
        "category": "security",
        "likelihood": "medium",
        "impact": "major",
    }
    path = _write_yaml(tmp_path, "risk.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_risk_invalid_category(tmp_path):
    doc = {
        "id": "risk-bad",
        "category": "unknown-category",  # not in enum
        "likelihood": "low",
        "impact": "minor",
    }
    path = _write_yaml(tmp_path, "risk.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Agent ==========


def test_agent_valid(tmp_path):
    doc = {
        "id": "test-agent",
        "runtime": "claude-code",
    }
    path = _write_yaml(tmp_path, "agent.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_agent_invalid_runtime(tmp_path):
    doc = {
        "id": "bad-agent",
        "runtime": "unknown-runtime",  # not in enum
    }
    path = _write_yaml(tmp_path, "agent.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Skill ==========


def test_skill_valid(tmp_path):
    doc = {
        "id": "test-skill",
        "harness": "claude",
    }
    path = _write_yaml(tmp_path, "skill.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_skill_invalid_harness(tmp_path):
    doc = {
        "id": "bad-skill",
        "harness": "unsupported",  # not in enum
    }
    path = _write_yaml(tmp_path, "skill.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Spec (Draft 2020-12) ==========


def test_spec_valid(tmp_path):
    doc = {
        "id": "spec-user-auth",
        "owner": "platform-team",
        "status": "draft",
    }
    path = _write_yaml(tmp_path, "spec.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_spec_invalid_id_pattern(tmp_path):
    """An id that does not match ^spec-...$ fails entity detection
    (by design) and falls back to the unknown-entity path with exit 0.
    Once inside the Spec path, an invalid status/required field DOES
    trigger a schema violation — see test_spec_invalid_status below."""
    doc = {
        "id": "invalid-id-no-prefix",
        "owner": "team",
        "status": "draft",
    }
    path = _write_yaml(tmp_path, "spec.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0
    assert "cannot infer entity type" in result.stderr


def test_spec_invalid_status(tmp_path):
    doc = {
        "id": "spec-demo-feature",
        "owner": "team",
        "status": "publishing",  # not in {draft, reviewing, approved, superseded}
    }
    path = _write_yaml(tmp_path, "spec.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== ADR (Draft 2020-12) ==========


def test_adr_valid(tmp_path):
    doc = {
        "id": "adr-0001-use-eks",
        "status": "accepted",
        "title": "Use EKS for container orchestration",
        "context": "We need a managed Kubernetes service.",
        "decision": "We will use Amazon EKS.",
    }
    path = _write_yaml(tmp_path, "adr.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_adr_invalid_id_pattern(tmp_path):
    """ADR detection requires id matching ^adr-NNNN-...$. Non-matching
    ids miss detection and fall back to the unknown-entity path."""
    doc = {
        "id": "adr-1-wrong",
        "status": "accepted",
        "title": "Test",
        "context": "Context",
        "decision": "Decision",
    }
    path = _write_yaml(tmp_path, "adr.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0
    assert "cannot infer entity type" in result.stderr


def test_adr_invalid_status(tmp_path):
    doc = {
        "id": "adr-0001-use-eks",
        "status": "inked",  # not in {proposed, accepted, rejected, deprecated, superseded}
        "title": "Use EKS",
        "context": "Ctx",
        "decision": "Dec",
    }
    path = _write_yaml(tmp_path, "adr.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


# ========== Fallback: unrecognized entity ==========


def test_unrecognized_entity_exits_zero_with_warning(tmp_path):
    doc = {"foo": "bar", "random": "data"}
    path = _write_yaml(tmp_path, "unknown.yaml", doc)
    result = _run([str(path)])
    assert result.returncode == 0
    assert "cannot infer entity type" in result.stderr
    assert "Deployment/Incident/Budget/Risk/Agent/Skill/Spec/ADR" in result.stderr
