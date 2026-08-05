"""Compiler SessionStart emission tests (#60).

The compiler emits a plugin-bundled SessionStart entry into hooks/hooks.json
from a DSL `hooks.session-start.runs` declaration, so /plugin install delivers
ontology-state injection. The runs path must stay inside the plugin root; a
`../`-escaping path (the pre-#60 bug) is a compile error.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

from tools.oma_compile.compile import (
    CompileError,
    _build_hooks_json,
    compile_plugin,
)

SESSION_START_MARKER = "oma-session-start"


def _write_plugin(root: Path, dsl: dict, hook_body: str | None = None) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    (plugin_dir / "hooks").mkdir(parents=True, exist_ok=True)
    if hook_body is not None:
        (plugin_dir / "hooks" / "session-start-ontology.sh").write_text(
            hook_body, encoding="utf-8"
        )
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out


BASE_DSL = {
    "version": 2,
    "plugin": "x-plugin",
    "mcp": {},
    "agents": [],
    "hooks": {"session-start": {"runs": "hooks/session-start-ontology.sh"}},
}


def test_session_start_entry_emitted(tmp_path):
    dsl_path = _write_plugin(tmp_path, BASE_DSL, hook_body="#!/usr/bin/env bash\n")
    compile_plugin(dsl_path, write=True)
    hooks_json = json.loads(
        (dsl_path.parent / "hooks" / "hooks.json").read_text(encoding="utf-8")
    )
    assert "SessionStart" in hooks_json
    entry = hooks_json["SessionStart"][0]
    assert entry["_oma"] == SESSION_START_MARKER
    assert entry["hooks"][0]["command"] == (
        'bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start-ontology.sh"'
    )


def test_escaping_runs_path_rejected(tmp_path):
    """A runs path that escapes the plugin root is a compile error (the #60 bug:
    ../../hooks/session-start.sh would not ship via /plugin install)."""
    dsl = dict(BASE_DSL)
    dsl["hooks"] = {"session-start": {"runs": "../../hooks/session-start.sh"}}
    # Provide the escaping target so _verify_hooks passes and the failure is
    # specifically the plugin-escape guard in the emitter.
    (tmp_path / "hooks").mkdir(parents=True, exist_ok=True)
    (tmp_path / "hooks" / "session-start.sh").write_text("#!/bin/bash\n")
    dsl_path = _write_plugin(tmp_path, dsl, hook_body=None)
    with pytest.raises(CompileError, match="escapes the plugin root"):
        compile_plugin(dsl_path, write=True)


def test_no_hooks_no_session_start(tmp_path):
    """A plugin without a hooks: block emits no SessionStart entry."""
    dsl = {k: v for k, v in BASE_DSL.items() if k != "hooks"}
    dsl_path = _write_plugin(tmp_path, dsl)
    compile_plugin(dsl_path, write=True)
    hooks_json_path = dsl_path.parent / "hooks" / "hooks.json"
    if hooks_json_path.exists():
        assert "SessionStart" not in json.loads(
            hooks_json_path.read_text(encoding="utf-8")
        )


def test_hand_authored_session_start_preserved(tmp_path):
    """A non-managed SessionStart entry survives recompiles (marker re-own)."""
    existing = {
        "SessionStart": [
            {"hooks": [{"type": "command", "command": "echo hand-authored"}]}
        ]
    }
    payload = _build_hooks_json(BASE_DSL, existing, tmp_path / "x.oma.yaml")
    events = payload["SessionStart"]
    assert any(e["hooks"][0]["command"] == "echo hand-authored" for e in events)
    assert any(e.get("_oma") == SESSION_START_MARKER for e in events)
