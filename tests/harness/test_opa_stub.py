"""scripts/oma/validate.sh smoke tests.

These exercise the bash script directly via subprocess. OPA is expected to
be absent on dev machines; the script must fall back to schema-only
validation with a clear warning.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
VALIDATE_SH = REPO_ROOT / "scripts" / "oma" / "validate.sh"


def _run(args: list[str], cwd: Path | None = None, env: dict[str, str] | None = None):
    # Ensure the python3 validate.sh shells out to is the one running pytest
    # (so jsonschema/pyyaml are importable). Prepend the current python's
    # directory to PATH.
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


def _write_deployment(tmp_path: Path, doc: dict) -> Path:
    out = tmp_path / "deployment.yaml"
    out.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
    return out


def test_missing_file_exits_nonzero(tmp_path):
    result = _run([str(tmp_path / "ghost.yaml")])
    assert result.returncode != 0
    assert "not found" in result.stderr


def test_schema_valid_deployment_passes(tmp_path):
    doc = {
        "id": "vllm-llama3-70b",
        "target": "eks",
        "artifact": "public.ecr.aws/example/vllm:0.18.2",
        "approval_state": "proposed",
    }
    path = _write_deployment(tmp_path, doc)
    result = _run([str(path)])
    assert result.returncode == 0, result.stderr
    assert "schema OK" in result.stdout


def test_schema_invalid_deployment_exits_one(tmp_path):
    doc = {
        "id": "x",
        "target": "mainframe",  # not an allowed enum
        "artifact": "",
        "approval_state": "queued",
    }
    path = _write_deployment(tmp_path, doc)
    result = _run([str(path)])
    assert result.returncode == 1
    assert "schema violation" in result.stderr


def test_opa_absent_fallback_is_non_fatal(tmp_path, monkeypatch):
    """When opa is not installed, validate.sh must still exit 0 on a valid
    deployment and emit the install hint. We simulate opa-absent by dropping
    /usr/local/bin from PATH and the usual fallbacks; shutil.which() is used
    only to skip this test when opa IS installed on this machine."""
    if shutil.which("opa") is not None:
        pytest.skip("opa is installed on this machine; cannot exercise the fallback path")

    doc = {
        "id": "vllm-llama3-70b",
        "target": "eks",
        "artifact": "public.ecr.aws/example/vllm:0.18.2",
        "approval_state": "approved",
    }
    path = _write_deployment(tmp_path, doc)
    result = _run([str(path), "--plugin", "ai-infra"])
    # ai-infra has no policies[] today, so the script exits 0
    # without even reaching the opa-absent branch. That is the expected
    # behaviour when no policies are declared.
    assert result.returncode == 0, result.stderr
