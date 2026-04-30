"""Round-trip test: DSL -> emitted files should be deterministic.

For M1 we do not yet ship a *.oma.yaml for any real plugin, so this test
drives the compiler against an inline synthetic DSL and asserts the
emitted shape. M2 will replace this with a per-plugin parametrized
test that compares to committed native files.
"""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from tools.oma_compile import compile_plugin, compile_workspace
from tools.oma_compile.compile import CompileError

import pytest

MINI_DSL = {
    "version": 1,
    "plugin": "agentic-platform",
    "agents": [
        {
            "id": "platform-architect",
            "runtime": "kiro",
            "description": "platform architect agent",
            "mcp": ["eks"],
            "welcomeMessage": "hello",
        }
    ],
    "mcp": {
        "eks": {
            "command": "uvx",
            "args": ["awslabs.eks-mcp-server==0.1.28"],
            "env": {"FASTMCP_LOG_LEVEL": "ERROR"},
        }
    },
    "triggers": [{"keyword": "platform-bootstrap", "route": "/oma:platform-bootstrap"}],
}


def _write_dsl(root: Path, dsl: dict) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    plugin_dir.mkdir(parents=True, exist_ok=True)
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out


def test_compile_emits_mcp_and_kiro(tmp_path):
    dsl_path = _write_dsl(tmp_path, MINI_DSL)
    result = compile_plugin(dsl_path, write=True)

    assert result.mcp_json_path.exists()
    mcp = json.loads(result.mcp_json_path.read_text(encoding="utf-8"))
    assert "eks" in mcp["mcpServers"]
    assert mcp["mcpServers"]["eks"]["args"] == ["awslabs.eks-mcp-server==0.1.28"]

    assert len(result.agent_json_paths) == 1
    agent = json.loads(result.agent_json_paths[0].read_text(encoding="utf-8"))
    assert agent["name"] == "platform-architect"
    assert agent["welcomeMessage"] == "hello"
    assert agent["autoApprove"]["fileWrites"] is False


def test_compile_is_idempotent(tmp_path):
    dsl_path = _write_dsl(tmp_path, MINI_DSL)
    compile_plugin(dsl_path, write=True)
    first = result_snapshot(dsl_path)
    compile_plugin(dsl_path, write=True)
    second = result_snapshot(dsl_path)
    assert first == second


def result_snapshot(dsl_path: Path) -> dict:
    plugin_dir = dsl_path.parent
    snap = {"mcp": (plugin_dir / ".mcp.json").read_text(encoding="utf-8")}
    for agent_file in (plugin_dir / "kiro-agents").glob("*.agent.json"):
        snap[agent_file.name] = agent_file.read_text(encoding="utf-8")
    return snap


def test_floating_version_rejected(tmp_path):
    dsl = dict(MINI_DSL)
    dsl["mcp"] = {"eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server@latest"]}}
    dsl_path = _write_dsl(tmp_path, dsl)
    with pytest.raises(CompileError):
        compile_plugin(dsl_path, write=False)


def test_undeclared_mcp_rejected(tmp_path):
    dsl = {
        "version": 1,
        "plugin": "x-plugin",
        "agents": [{"id": "a", "runtime": "claude-code", "mcp": ["ghost"]}],
        "mcp": {
            "eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}
        },
    }
    dsl_path = _write_dsl(tmp_path, dsl)
    with pytest.raises(CompileError):
        compile_plugin(dsl_path, write=False)


def test_workspace_merges_triggers(tmp_path):
    dsl_path = _write_dsl(tmp_path, MINI_DSL)
    # Point workspace output at the tmp path by monkey-patching TRIGGERS_OUT.
    from tools.oma_compile import compile as compile_mod

    original = compile_mod.TRIGGERS_OUT
    compile_mod.TRIGGERS_OUT = tmp_path / ".omao" / "triggers.json"
    try:
        compile_workspace([dsl_path], write=True)
        merged = json.loads(compile_mod.TRIGGERS_OUT.read_text(encoding="utf-8"))
    finally:
        compile_mod.TRIGGERS_OUT = original

    assert merged["triggers"][0]["keyword"] == "platform-bootstrap"
