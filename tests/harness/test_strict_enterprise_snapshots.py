"""Snapshot tests for strict-enterprise error messages.

These tests ensure that the five user-visible error strings emitted by
`oma compile --strict-enterprise` remain stable. Downstream users may grep/alert
on these messages, so any wording change should be intentional.

If you need to change an error string:
  1. Update the constant in tools/oma_compile/compile.py
  2. Bump SNAPSHOT_VERSION in this file
  3. Update the corresponding snapshot strings below
  4. Commit both changes together with a clear justification

SNAPSHOT_VERSION tracks the current expected wording. Increment when changing.
"""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from tools.oma_compile.compile import (
    ERR_APPROVAL_CHAIN_EMPTY,
    ERR_ARTIFACT_DIGEST,
    ERR_ARTIFACT_LEGACY_STRING,
    ERR_RISK_MISSING_CLASSIFICATION,
    ERR_V1_REJECTED,
    enforce_strict_enterprise,
)

SNAPSHOT_VERSION = 1


def test_err_v1_rejected_format():
    """Snapshot: version 2 requirement error."""
    actual = ERR_V1_REJECTED.format(
        path="plugins/legacy-plugin/legacy-plugin.oma.yaml",
        version=1,
    )
    expected = (
        "plugins/legacy-plugin/legacy-plugin.oma.yaml: strict-enterprise requires "
        "version: 2 (found version=1). Fix: bump `version: 1` to `version: 2` in the DSL."
    )
    assert actual == expected, f"SNAPSHOT_VERSION={SNAPSHOT_VERSION}"


def test_err_approval_chain_empty_format():
    """Snapshot: approved deployment missing approval_chain."""
    actual = ERR_APPROVAL_CHAIN_EMPTY.format(dep_id="vllm-llama3-70b")
    expected = (
        "deployment 'vllm-llama3-70b': approval_state=approved but approval_chain "
        "is empty. Fix: append one approval link with approver/approved_at/reason."
    )
    assert actual == expected, f"SNAPSHOT_VERSION={SNAPSHOT_VERSION}"


def test_err_artifact_digest_format():
    """Snapshot: malformed or missing artifact.digest."""
    actual = ERR_ARTIFACT_DIGEST.format(dep_id="vllm-llama3-70b", digest="")
    expected = (
        "deployment 'vllm-llama3-70b': artifact.digest missing or malformed "
        "(got ''). Fix: provide sha256:<64 hex>."
    )
    assert actual == expected, f"SNAPSHOT_VERSION={SNAPSHOT_VERSION}"


def test_err_artifact_legacy_string_format():
    """Snapshot: legacy string artifact rejected."""
    actual = ERR_ARTIFACT_LEGACY_STRING.format(dep_id="vllm-llama3-70b")
    expected = (
        "deployment 'vllm-llama3-70b': legacy string artifact is rejected under "
        "strict-enterprise. Fix: replace with the object form (uri/digest)."
    )
    assert actual == expected, f"SNAPSHOT_VERSION={SNAPSHOT_VERSION}"


def test_err_risk_missing_classification_format():
    """Snapshot: risk missing OWASP/NIST classification."""
    actual = ERR_RISK_MISSING_CLASSIFICATION.format(risk_id="legacy-oracle")
    expected = (
        "risk 'legacy-oracle': strict-enterprise requires at least one of "
        "owasp_llm_top10_id (LLM01..LLM10) or nist_ai_rmf_subcategory "
        "(e.g. MEASURE.2.6). Fix: add the classification that best matches "
        "this risk."
    )
    assert actual == expected, f"SNAPSHOT_VERSION={SNAPSHOT_VERSION}"


def test_enforce_strict_enterprise_uses_err_v1_rejected(tmp_path, monkeypatch):
    """Integration: enforce_strict_enterprise emits ERR_V1_REJECTED for v1 DSL."""
    plugin_dir = tmp_path / "plugins" / "legacy-plugin"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 1,
        "plugin": "legacy-plugin",
        "mcp": {
            "eks": {
                "command": "uvx",
                "args": ["awslabs.eks-mcp-server==0.1.28"],
            }
        },
    }
    dsl_path = plugin_dir / "legacy-plugin.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])

    expected = ERR_V1_REJECTED.format(
        path=Path("plugins/legacy-plugin/legacy-plugin.oma.yaml"),
        version=1,
    )
    assert expected in errors, f"Expected exact match for ERR_V1_REJECTED. Got: {errors}"


def test_enforce_strict_enterprise_uses_err_approval_chain_empty(tmp_path, monkeypatch):
    """Integration: enforce_strict_enterprise emits ERR_APPROVAL_CHAIN_EMPTY."""
    plugin_dir = tmp_path / "plugins" / "agentic-platform"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 2,
        "plugin": "agentic-platform",
        "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
    }
    dsl_path = plugin_dir / "agentic-platform.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    deploy_dir = tmp_path / ".omao" / "ontology" / "deployments"
    deploy_dir.mkdir(parents=True)
    (deploy_dir / "vllm.json").write_text(
        json.dumps({
            "id": "vllm-llama3-70b",
            "target": "eks",
            "artifact": {"uri": "public.ecr.aws/example/vllm:0.18.2", "digest": "sha256:" + "a" * 64},
            "approval_state": "approved",
        }),
        encoding="utf-8",
    )

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])

    expected = ERR_APPROVAL_CHAIN_EMPTY.format(dep_id="vllm-llama3-70b")
    assert expected in errors, f"Expected exact match for ERR_APPROVAL_CHAIN_EMPTY. Got: {errors}"


def test_enforce_strict_enterprise_uses_err_artifact_digest(tmp_path, monkeypatch):
    """Integration: enforce_strict_enterprise emits ERR_ARTIFACT_DIGEST."""
    plugin_dir = tmp_path / "plugins" / "agentic-platform"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 2,
        "plugin": "agentic-platform",
        "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
    }
    dsl_path = plugin_dir / "agentic-platform.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    deploy_dir = tmp_path / ".omao" / "ontology" / "deployments"
    deploy_dir.mkdir(parents=True)
    (deploy_dir / "vllm.json").write_text(
        json.dumps({
            "id": "vllm-llama3-70b",
            "target": "eks",
            "artifact": {"uri": "public.ecr.aws/example/vllm:0.18.2", "digest": "invalid"},
            "approval_state": "pending",
        }),
        encoding="utf-8",
    )

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])

    expected = ERR_ARTIFACT_DIGEST.format(dep_id="vllm-llama3-70b", digest="invalid")
    assert expected in errors, f"Expected exact match for ERR_ARTIFACT_DIGEST. Got: {errors}"


def test_enforce_strict_enterprise_uses_err_artifact_legacy_string(tmp_path, monkeypatch):
    """Integration: enforce_strict_enterprise emits ERR_ARTIFACT_LEGACY_STRING."""
    plugin_dir = tmp_path / "plugins" / "agentic-platform"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 2,
        "plugin": "agentic-platform",
        "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
    }
    dsl_path = plugin_dir / "agentic-platform.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    deploy_dir = tmp_path / ".omao" / "ontology" / "deployments"
    deploy_dir.mkdir(parents=True)
    (deploy_dir / "vllm.json").write_text(
        json.dumps({
            "id": "vllm-llama3-70b",
            "target": "eks",
            "artifact": "public.ecr.aws/example/vllm:0.18.2",
        }),
        encoding="utf-8",
    )

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])

    expected = ERR_ARTIFACT_LEGACY_STRING.format(dep_id="vllm-llama3-70b")
    assert expected in errors, f"Expected exact match for ERR_ARTIFACT_LEGACY_STRING. Got: {errors}"


def test_enforce_strict_enterprise_uses_err_risk_missing_classification(tmp_path, monkeypatch):
    """Integration: enforce_strict_enterprise emits ERR_RISK_MISSING_CLASSIFICATION."""
    plugin_dir = tmp_path / "plugins" / "agentic-platform"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 2,
        "plugin": "agentic-platform",
        "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
    }
    dsl_path = plugin_dir / "agentic-platform.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    risks_dir = tmp_path / ".omao" / "ontology" / "risks"
    risks_dir.mkdir(parents=True)
    (risks_dir / "legacy.json").write_text(
        json.dumps({
            "id": "legacy-oracle",
            "category": "replatform",
            "likelihood": "medium",
            "impact": "major",
        }),
        encoding="utf-8",
    )

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])

    expected = ERR_RISK_MISSING_CLASSIFICATION.format(risk_id="legacy-oracle")
    assert expected in errors, f"Expected exact match for ERR_RISK_MISSING_CLASSIFICATION. Got: {errors}"
