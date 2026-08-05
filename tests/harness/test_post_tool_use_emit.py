"""Compiler PostToolUse emission tests.

The compiler emits a plugin-bundled PostToolUse entry into hooks/hooks.json from
a DSL `hooks.post-tool-use.runs` declaration, so /plugin install delivers
tool-call auditing. It must coexist with the policies-derived PreToolUse entry
(each re-owns only its own _oma-marked entry). The runs path must stay inside
the plugin root (the same plugin-escape guard as SessionStart).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

from tools.oma_compile.compile import (
    HARNESS_HOOK_MARKER,
    POST_TOOL_USE_MARKER,
    CompileError,
    _build_hooks_json,
    compile_plugin,
)


def _write_plugin(root: Path, dsl: dict) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    (plugin_dir / "hooks").mkdir(parents=True, exist_ok=True)
    (plugin_dir / "hooks" / "audit-posttooluse.sh").write_text(
        "#!/usr/bin/env bash\n", encoding="utf-8"
    )
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out


BASE_DSL = {
    "version": 2,
    "plugin": "x-plugin",
    "mcp": {},
    "agents": [],
    "hooks": {"post-tool-use": {"runs": "hooks/audit-posttooluse.sh"}},
}


def test_post_tool_use_entry_emitted(tmp_path):
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)
    hooks_json = json.loads(
        (dsl_path.parent / "hooks" / "hooks.json").read_text(encoding="utf-8")
    )
    assert hooks_json["PostToolUse"][0]["_oma"] == POST_TOOL_USE_MARKER
    assert hooks_json["PostToolUse"][0]["hooks"][0]["command"] == (
        'bash "${CLAUDE_PLUGIN_ROOT}/hooks/audit-posttooluse.sh"'
    )


def test_coexists_with_policies_pretooluse(tmp_path):
    """A policies-derived PreToolUse and a hooks-declared PostToolUse coexist."""
    dsl = dict(BASE_DSL)
    dsl["policies"] = [
        {"id": "r", "enforce": {"tool": "Write", "deny_if": {"file_path_matches": "x"}}}
    ]
    payload = _build_hooks_json(dsl, None, tmp_path / "x.oma.yaml")
    assert payload["PreToolUse"][0]["_oma"] == HARNESS_HOOK_MARKER
    assert payload["PostToolUse"][0]["_oma"] == POST_TOOL_USE_MARKER


def test_escaping_runs_path_rejected(tmp_path):
    dsl = dict(BASE_DSL)
    dsl["hooks"] = {"post-tool-use": {"runs": "../../hooks/audit-posttooluse.sh"}}
    dsl_path = _write_plugin(tmp_path, dsl)
    (tmp_path / "hooks").mkdir(parents=True, exist_ok=True)
    (tmp_path / "hooks" / "audit-posttooluse.sh").write_text(
        "#!/bin/bash\n", encoding="utf-8"
    )
    with pytest.raises(CompileError, match="escapes the plugin root"):
        compile_plugin(dsl_path, write=True)


def test_hand_authored_post_tool_use_preserved(tmp_path):
    existing = {
        "PostToolUse": [
            {"hooks": [{"type": "command", "command": "echo hand-authored"}]},
            {
                "_oma": POST_TOOL_USE_MARKER,
                "hooks": [{"type": "command", "command": "STALE"}],
            },
        ]
    }
    payload = _build_hooks_json(BASE_DSL, existing, tmp_path / "x.oma.yaml")
    commands = [e["hooks"][0]["command"] for e in payload["PostToolUse"]]
    assert "echo hand-authored" in commands
    assert 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/audit-posttooluse.sh"' in commands
    assert "STALE" not in commands
    assert sum(
        1 for e in payload["PostToolUse"] if e.get("_oma") == POST_TOOL_USE_MARKER
    ) == 1


def test_dropping_declaration_removes_managed_keeps_hand_authored(tmp_path):
    existing = {
        "PostToolUse": [
            {"hooks": [{"type": "command", "command": "echo hand-authored"}]},
            {
                "_oma": POST_TOOL_USE_MARKER,
                "hooks": [{"type": "command", "command": "STALE"}],
            },
        ]
    }
    dsl = {"version": 2, "plugin": "x-plugin", "hooks": {}}
    payload = _build_hooks_json(dsl, existing, tmp_path / "x.oma.yaml")
    commands = [e["hooks"][0]["command"] for e in payload["PostToolUse"]]
    assert commands == ["echo hand-authored"]
