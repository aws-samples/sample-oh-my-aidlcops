"""DSL v2 workflow DAG validation tests.

The compiler accepts workflows only when ``version: 2``. It checks:
  - duplicate step ids
  - agent_ref resolves to a declared agent
  - depends_on references in-workflow step ids
  - depends_on graph is a DAG (no cycles)
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from tools.oma_compile import compile_plugin
from tools.oma_compile.compile import CompileError


def _write(root: Path, dsl: dict) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    plugin_dir.mkdir(parents=True, exist_ok=True)
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out


def _base_v2(plugin: str = "ai-infra") -> dict:
    return {
        "version": 2,
        "plugin": plugin,
        "agents": [
            {"id": "platform-architect", "runtime": "kiro", "mcp": ["eks"]},
            {"id": "vllm-deployer", "runtime": "kiro", "mcp": ["eks"]},
        ],
        "mcp": {
            "eks": {
                "command": "uvx",
                "args": ["awslabs.eks-mcp-server==0.1.28"],
            }
        },
    }


def test_v2_workflow_valid(tmp_path):
    dsl = {
        **_base_v2(),
        "workflows": {
            "platform-bootstrap": {
                "steps": [
                    {"id": "preflight", "agent_ref": "platform-architect"},
                    {
                        "id": "provision",
                        "agent_ref": "vllm-deployer",
                        "depends_on": ["preflight"],
                    },
                ]
            }
        },
    }
    dsl_path = _write(tmp_path, dsl)
    # Compiles without error.
    compile_plugin(dsl_path, write=False)


def test_v2_workflow_unknown_agent_ref(tmp_path):
    dsl = {
        **_base_v2(),
        "workflows": {
            "bad": {
                "steps": [{"id": "s1", "agent_ref": "ghost-agent"}]
            }
        },
    }
    dsl_path = _write(tmp_path, dsl)
    with pytest.raises(CompileError, match="undeclared agent_ref"):
        compile_plugin(dsl_path, write=False)


def test_v2_workflow_depends_on_unknown_step(tmp_path):
    dsl = {
        **_base_v2(),
        "workflows": {
            "bad": {
                "steps": [
                    {"id": "s1", "agent_ref": "platform-architect"},
                    {"id": "s2", "agent_ref": "vllm-deployer", "depends_on": ["missing"]},
                ]
            }
        },
    }
    dsl_path = _write(tmp_path, dsl)
    with pytest.raises(CompileError, match="depends_on"):
        compile_plugin(dsl_path, write=False)


def test_v2_workflow_cycle_detected(tmp_path):
    dsl = {
        **_base_v2(),
        "workflows": {
            "loop": {
                "steps": [
                    {"id": "a", "agent_ref": "platform-architect", "depends_on": ["b"]},
                    {"id": "b", "agent_ref": "vllm-deployer", "depends_on": ["a"]},
                ]
            }
        },
    }
    dsl_path = _write(tmp_path, dsl)
    with pytest.raises(CompileError, match="cycle"):
        compile_plugin(dsl_path, write=False)


def test_v2_workflow_duplicate_step_id(tmp_path):
    dsl = {
        **_base_v2(),
        "workflows": {
            "dup": {
                "steps": [
                    {"id": "s", "agent_ref": "platform-architect"},
                    {"id": "s", "agent_ref": "vllm-deployer"},
                ]
            }
        },
    }
    dsl_path = _write(tmp_path, dsl)
    with pytest.raises(CompileError, match="duplicate step id"):
        compile_plugin(dsl_path, write=False)
