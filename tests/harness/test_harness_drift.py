"""check_drift regression tests for the harness-managed artifacts.

check_drift previously only compared .mcp.json and kiro-agents/*.agent.json
against their DSL — hooks/hooks.json, hooks/harness-rules.json, and
hooks/enforce.py were never checked, so a stale or hand-edited hooks.json
(e.g. missing the top-level "hooks" wrapper Claude Code 2.x requires, or
carrying a compiler-managed entry left over after its DSL declaration was
removed) passed `oma-compile --check` silently. These tests pin the
extended behavior so that class of drift is caught going forward.
"""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from tools.oma_compile.compile import (
    HARNESS_ENFORCER_SRC,
    check_drift,
    compile_plugin,
)


def _write_plugin(root: Path, dsl: dict) -> Path:
    plugin_dir = root / "plugins" / dsl["plugin"]
    (plugin_dir / "hooks").mkdir(parents=True, exist_ok=True)
    (plugin_dir / "hooks" / "session-start-ontology.sh").write_text(
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
    "hooks": {"session-start": {"runs": "hooks/session-start-ontology.sh"}},
}

POLICY_DSL = {
    "version": 2,
    "plugin": "y-plugin",
    "mcp": {},
    "agents": [],
    "policies": [
        {
            "id": "deny-secret-file-write",
            "severity": "blocking",
            "phase": ["construction"],
            "description": "Block Write to secret-bearing files.",
            "enforce": {
                "tool": "Write",
                "deny_if": {"file_path_matches": "\\.env$"},
                "decision": "deny",
                "reason": "no secrets in Write",
            },
        }
    ],
}


def test_freshly_compiled_hooks_json_has_no_drift(tmp_path):
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)
    assert check_drift([dsl_path]) == []


def test_unwrapped_hooks_json_is_flagged_as_drift(tmp_path):
    """The exact shape of the shipped bug: event keys at the top level of
    hooks.json instead of nested under a "hooks" key."""
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)

    hooks_json_path = dsl_path.parent / "hooks" / "hooks.json"
    wrapped = json.loads(hooks_json_path.read_text(encoding="utf-8"))
    hooks_json_path.write_text(
        json.dumps(wrapped["hooks"], indent=2) + "\n", encoding="utf-8"
    )

    drift = check_drift([dsl_path])
    assert any("hooks.json" in d for d in drift), drift


def test_stale_managed_entry_after_dsl_removal_is_flagged(tmp_path):
    """A compiler-managed entry (e.g. a removed hooks.session-start:
    declaration) left behind in a committed hooks.json must be reported,
    not silently treated as hand-authored content."""
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)

    dsl = dict(BASE_DSL)
    dsl.pop("hooks")
    dsl_path.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")

    drift = check_drift([dsl_path])
    assert any("hooks.json" in d for d in drift), drift


def test_policy_rules_and_enforcer_drift_detected(tmp_path):
    dsl_path = _write_plugin(tmp_path, POLICY_DSL)
    compile_plugin(dsl_path, write=True)
    assert check_drift([dsl_path]) == []

    rules_path = dsl_path.parent / "hooks" / "harness-rules.json"
    rules_path.write_text(json.dumps({"rules": []}) + "\n", encoding="utf-8")
    drift = check_drift([dsl_path])
    assert any("harness-rules.json" in d for d in drift), drift

    # restore, then corrupt the bundled enforcer instead.
    compile_plugin(dsl_path, write=True)
    enforcer_path = dsl_path.parent / "hooks" / "enforce.py"
    enforcer_path.write_text("# tampered\n", encoding="utf-8")
    drift = check_drift([dsl_path])
    assert any(str(HARNESS_ENFORCER_SRC) in d for d in drift), drift
