"""DSL v2 telemetry / policies body validation (v0.4)."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from tools.oma_compile import compile_plugin
from tools.oma_compile.compile import CompileError

REPO_ROOT = Path(__file__).resolve().parents[2]


def _write(root: Path, dsl: dict) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    plugin_dir.mkdir(parents=True, exist_ok=True)
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out


def _base(plugin: str = "ai-infra") -> dict:
    return {
        "version": 2,
        "plugin": plugin,
        "agents": [
            {"id": "platform-architect", "runtime": "kiro", "mcp": ["eks"]}
        ],
        "mcp": {
            "eks": {
                "command": "uvx",
                "args": ["awslabs.eks-mcp-server==0.1.28"],
            }
        },
    }


def test_telemetry_full_shape_accepted(tmp_path):
    dsl = {
        **_base(),
        "telemetry": {
            "traces": {
                "endpoint": "http://otel-collector:4317",
                "protocol": "grpc",
                "sampler": "parentbased_traceidratio",
                "sampler_ratio": 0.1,
            },
            "metrics": {
                "endpoint": "http://otel-collector:4318",
                "interval_seconds": 30,
            },
            "logs": {
                "endpoint": "http://otel-collector:4319",
                "level": "info",
            },
        },
    }
    compile_plugin(_write(tmp_path, dsl), write=False)


def test_telemetry_sampler_ratio_out_of_range(tmp_path):
    dsl = {
        **_base(),
        "telemetry": {
            "traces": {
                "endpoint": "http://otel:4317",
                "sampler_ratio": 2.0,
            }
        },
    }
    with pytest.raises(CompileError, match="sampler_ratio"):
        compile_plugin(_write(tmp_path, dsl), write=False)


def test_telemetry_metrics_interval_too_small(tmp_path):
    dsl = {
        **_base(),
        "telemetry": {
            "metrics": {"endpoint": "http://otel:4318", "interval_seconds": 5}
        },
    }
    with pytest.raises(CompileError, match="interval_seconds"):
        compile_plugin(_write(tmp_path, dsl), write=False)


def test_policies_valid_ref_accepted(tmp_path):
    dsl = {
        **_base(),
        "policies": [
            {
                "id": "require-approval",
                "rego_ref": "policies/examples/deployment-approval.rego",
                "severity": "blocking",
                "phase": ["construction"],
            }
        ],
    }
    compile_plugin(_write(tmp_path, dsl), write=False)


def test_policies_missing_rego_file_rejected(tmp_path):
    dsl = {
        **_base(),
        "policies": [
            {
                "id": "ghost",
                "rego_ref": "policies/nope/does-not-exist.rego",
                "severity": "blocking",
                "phase": ["construction"],
            }
        ],
    }
    with pytest.raises(CompileError, match="missing file"):
        compile_plugin(_write(tmp_path, dsl), write=False)


def test_policies_non_rego_path_rejected(tmp_path):
    dsl = {
        **_base(),
        "policies": [
            {
                "id": "bad-ext",
                "rego_ref": "README.md",
                "severity": "warning",
                "phase": ["operations"],
            }
        ],
    }
    with pytest.raises(CompileError, match=r"\.rego\$"):
        compile_plugin(_write(tmp_path, dsl), write=False)
