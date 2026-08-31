"""Compiler Stop / StopFailure emission tests.

The compiler emits plugin-bundled Stop and StopFailure entries into
hooks/hooks.json from DSL `hooks.stop.runs` / `hooks.stop-failure.runs`
declarations, so /plugin install delivers phase-gate enforcement. Each event
re-owns only its own _oma-marked entry, so hand-authored entries in the same
group survive recompiles. The runs path must stay inside the plugin root (the
same plugin-escape guard as SessionStart).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.oma_compile.compile import (
    STOP_FAILURE_MARKER,
    STOP_MARKER,
    CompileError,
    _build_hooks_json,
    compile_plugin,
)

from .conftest import write_plugin


def _write_plugin(root: Path, dsl: dict) -> Path:
    return write_plugin(root, dsl, scripts={"hooks/stop-gate.sh": "#!/usr/bin/env bash\n"})


BASE_DSL = {
    "version": 2,
    "plugin": "x-plugin",
    "mcp": {},
    "agents": [],
    "hooks": {
        "stop": {"runs": "hooks/stop-gate.sh"},
        "stop-failure": {"runs": "hooks/stop-gate.sh"},
    },
}


def test_stop_and_stop_failure_entries_emitted(tmp_path):
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)
    hooks_json = json.loads(
        (dsl_path.parent / "hooks" / "hooks.json").read_text(encoding="utf-8")
    )["hooks"]
    assert hooks_json["Stop"][0]["_oma"] == STOP_MARKER
    assert hooks_json["StopFailure"][0]["_oma"] == STOP_FAILURE_MARKER
    expected_cmd = 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh"'
    assert hooks_json["Stop"][0]["hooks"][0]["command"] == expected_cmd
    assert hooks_json["StopFailure"][0]["hooks"][0]["command"] == expected_cmd


def test_stop_only_does_not_emit_stop_failure(tmp_path):
    dsl = dict(BASE_DSL)
    dsl["hooks"] = {"stop": {"runs": "hooks/stop-gate.sh"}}
    dsl_path = _write_plugin(tmp_path, dsl)
    compile_plugin(dsl_path, write=True)
    hooks_json = json.loads(
        (dsl_path.parent / "hooks" / "hooks.json").read_text(encoding="utf-8")
    )["hooks"]
    assert "Stop" in hooks_json
    assert "StopFailure" not in hooks_json


def test_escaping_runs_path_rejected(tmp_path):
    """A stop runs path that escapes the plugin root is a compile error."""
    dsl = dict(BASE_DSL)
    dsl["hooks"] = {"stop": {"runs": "../../hooks/stop-gate.sh"}}
    dsl_path = _write_plugin(tmp_path, dsl)
    # Create the escaping target so _verify_hooks passes and the failure is
    # specifically the plugin-escape guard in the emitter (not "missing script").
    (tmp_path / "hooks").mkdir(parents=True, exist_ok=True)
    (tmp_path / "hooks" / "stop-gate.sh").write_text("#!/bin/bash\n", encoding="utf-8")
    with pytest.raises(CompileError, match="escapes the plugin root"):
        compile_plugin(dsl_path, write=True)


def test_hand_authored_stop_preserved(tmp_path):
    """A non-managed Stop entry survives recompiles (per-event marker re-own)."""
    existing = {
        "Stop": [
            {"hooks": [{"type": "command", "command": "echo hand-authored"}]},
            {"_oma": STOP_MARKER, "hooks": [{"type": "command", "command": "STALE"}]},
        ]
    }
    payload = _build_hooks_json(BASE_DSL, existing, tmp_path / "x.oma.yaml")
    commands = [e["hooks"][0]["command"] for e in payload["Stop"]]
    assert "echo hand-authored" in commands
    assert 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/stop-gate.sh"' in commands
    assert "STALE" not in commands
    assert sum(1 for e in payload["Stop"] if e.get("_oma") == STOP_MARKER) == 1


def test_dropping_stop_removes_managed_keeps_hand_authored(tmp_path):
    existing = {
        "Stop": [
            {"hooks": [{"type": "command", "command": "echo hand-authored"}]},
            {"_oma": STOP_MARKER, "hooks": [{"type": "command", "command": "STALE"}]},
        ]
    }
    dsl = {"version": 2, "plugin": "x-plugin", "hooks": {}}
    payload = _build_hooks_json(dsl, existing, tmp_path / "x.oma.yaml")
    commands = [e["hooks"][0]["command"] for e in payload["Stop"]]
    assert commands == ["echo hand-authored"]


def test_timeout_ms_passthrough(tmp_path):
    dsl = {
        "version": 2,
        "plugin": "x-plugin",
        "hooks": {"stop": {"runs": "hooks/stop-gate.sh", "timeout_ms": 5000}},
    }
    payload = _build_hooks_json(dsl, None, tmp_path / "x.oma.yaml")
    assert payload["Stop"][0]["hooks"][0]["timeout"] == 5000
