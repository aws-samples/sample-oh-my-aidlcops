"""Tests for `oma compile --strict-enterprise` gate logic.

The gate is implemented as tools.oma_compile.compile.enforce_strict_enterprise
and exposed on the CLI via `python -m tools.oma_compile --strict-enterprise`.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

from tools.oma_compile.compile import REPO_ROOT, enforce_strict_enterprise


def _write_dsl_v1(tmp_path: Path) -> Path:
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
    return dsl_path


def test_rejects_v1_dsl(tmp_path, monkeypatch):
    path = _write_dsl_v1(tmp_path)
    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([path])
    assert any("version: 2" in e for e in errors), errors


def test_passes_on_v2_repo():
    """The real repository already holds only v2 DSL files (post-migration)."""
    dsl_files = sorted((REPO_ROOT / "plugins").glob("*/*.oma.yaml"))
    assert dsl_files, "expected at least one migrated plugin DSL"
    errors = enforce_strict_enterprise(dsl_files)
    # Filter out deployment/risk errors that depend on .omao/ontology/* state
    # (the dev checkout does not carry committed ontology instances).
    version_errors = [e for e in errors if "version: 2" in e]
    assert version_errors == [], version_errors


def test_rejects_deployment_without_approval_chain(tmp_path, monkeypatch):
    plugin_dir = tmp_path / "plugins" / "ai-infra"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 2,
        "plugin": "ai-infra",
        "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
    }
    dsl_path = plugin_dir / "ai-infra.oma.yaml"
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    deploy_dir = tmp_path / ".omao" / "ontology" / "deployments"
    deploy_dir.mkdir(parents=True)
    (deploy_dir / "vllm.json").write_text(
        json.dumps({
            "id": "vllm-llama3-70b",
            "target": "eks",
            "artifact": "public.ecr.aws/example/vllm:0.18.2",
            "approval_state": "approved",
        }),
        encoding="utf-8",
    )

    monkeypatch.setattr("tools.oma_compile.compile.REPO_ROOT", tmp_path)
    errors = enforce_strict_enterprise([dsl_path])
    assert any("approval_chain" in e for e in errors), errors
    assert any("legacy string artifact" in e for e in errors), errors


def test_rejects_risk_without_classification(tmp_path, monkeypatch):
    plugin_dir = tmp_path / "plugins" / "ai-infra"
    plugin_dir.mkdir(parents=True)
    (plugin_dir / "ai-infra.oma.yaml").write_text(
        yaml.safe_dump({
            "version": 2,
            "plugin": "ai-infra",
            "mcp": {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}},
        }, sort_keys=False),
        encoding="utf-8",
    )
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
    dsl_path = plugin_dir / "ai-infra.oma.yaml"
    errors = enforce_strict_enterprise([dsl_path])
    assert any("legacy-oracle" in e for e in errors), errors
    assert any("owasp_llm_top10_id" in e for e in errors), errors


def test_cli_exit_code_on_strict_failure(tmp_path):
    """End-to-end: python -m tools.oma_compile --strict-enterprise must exit 1 when gates fail."""
    # Craft a tiny workspace with a v1 plugin only.
    plugin_dir = tmp_path / "plugins" / "legacy-plugin"
    plugin_dir.mkdir(parents=True)
    dsl = {
        "version": 1,
        "plugin": "legacy-plugin",
        "mcp": {
            "eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}
        },
    }
    (plugin_dir / "legacy-plugin.oma.yaml").write_text(
        yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8"
    )

    env = {**os.environ, "PYTHONPATH": str(REPO_ROOT)}
    proc = subprocess.run(
        [sys.executable, "-c",
         "import sys; sys.path.insert(0, r'%s');"
         "from tools.oma_compile import compile as c;"
         "c.REPO_ROOT = __import__('pathlib').Path(r'%s');"
         "from tools.oma_compile.__main__ import main;"
         "sys.exit(main(['--strict-enterprise']))" % (REPO_ROOT, tmp_path)],
        env=env,
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 1, (proc.stdout, proc.stderr)
    assert "strict-enterprise gate failed" in proc.stderr
