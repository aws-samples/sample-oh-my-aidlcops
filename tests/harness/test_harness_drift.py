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

import pytest
import yaml

from tools.oma_compile.compile import (
    HARNESS_ENFORCER_SRC,
    CompileError,
    check_drift,
    compile_plugin,
)

from .conftest import write_plugin


def _write_plugin(root: Path, dsl: dict) -> Path:
    return write_plugin(
        root, dsl, scripts={"hooks/session-start-ontology.sh": "#!/usr/bin/env bash\n"}
    )


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


def test_orphaned_rules_and_enforcer_flagged_after_policies_removed(tmp_path):
    """A plugin whose policies: block is removed from the DSL must not keep
    shipping a stale, inert enforcer — the #1 regression this PR fixes for
    agenticops. compile_plugin(write=True) must delete both files, and
    check_drift must flag them as orphaned if something else leaves them in
    place (e.g. a hand-applied patch)."""
    dsl_path = _write_plugin(tmp_path, POLICY_DSL)
    compile_plugin(dsl_path, write=True)
    rules_path = dsl_path.parent / "hooks" / "harness-rules.json"
    enforcer_path = dsl_path.parent / "hooks" / "enforce.py"
    assert rules_path.exists() and enforcer_path.exists()

    dsl_without_policies = {k: v for k, v in POLICY_DSL.items() if k != "policies"}
    dsl_path.write_text(yaml.safe_dump(dsl_without_policies, sort_keys=False), encoding="utf-8")

    # check_drift (read-only) must flag both as orphaned rather than reporting
    # clean, and must not delete them itself.
    drift = check_drift([dsl_path])
    assert any("harness-rules.json" in d and "orphaned" in d for d in drift), drift
    assert any("enforce.py" in d and "orphaned" in d for d in drift), drift
    assert rules_path.exists() and enforcer_path.exists()

    # An actual recompile clears them, and check_drift goes clean.
    compile_plugin(dsl_path, write=True)
    assert not rules_path.exists()
    assert not enforcer_path.exists()
    assert check_drift([dsl_path]) == []


def test_unmarked_managed_entry_with_no_marked_copy_flagged(tmp_path):
    """A managed hooks.json entry that lost its _oma marker entirely (e.g. a
    bad merge that dropped the marker while duplicating the Stop entry) must
    be reported even though the merge-based comparison alone cannot see it:
    the corrupted entry looks like unrelated hand-authored content once its
    marker is gone, so it gets folded into "expected" and the merge matches
    on-disk content byte-for-byte."""
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)
    assert check_drift([dsl_path]) == []

    hooks_json_path = dsl_path.parent / "hooks" / "hooks.json"
    payload = json.loads(hooks_json_path.read_text(encoding="utf-8"))
    managed_entry = payload["hooks"]["SessionStart"][0]
    unmarked = dict(managed_entry)
    unmarked.pop("_oma")
    # Replace (not append) the marked entry — the marker is gone, period.
    payload["hooks"]["SessionStart"] = [unmarked]
    hooks_json_path.write_text(json.dumps(payload), encoding="utf-8")

    drift = check_drift([dsl_path])
    assert any("missing its _oma" in d for d in drift), drift


def test_hand_authored_duplicate_alongside_marked_entry_not_flagged(tmp_path):
    """A hand-authored entry that happens to have identical content to the
    compiler-managed one (e.g. a user copies it to add a second matcher) must
    NOT be flagged as marker loss as long as the correctly marked entry is
    still present — that coexistence is the documented survival behavior
    (see test_hand_authored_session_start_preserved) and is indistinguishable
    from marker loss by content alone, so only "the marker is missing
    entirely" is treated as corruption.

    Exercises _find_unmarked_managed_duplicates directly rather than through
    check_drift's full byte-for-byte file comparison: appending any entry
    after the managed one also trips the *unrelated*, pre-existing "recompile
    would reorder the managed entry to the end" drift in _build_hooks_json's
    merge — a real, separate drift signal this test isn't about."""
    from tools.oma_compile.compile import SESSION_START_MARKER, _find_unmarked_managed_duplicates

    managed_entry = {
        "_oma": SESSION_START_MARKER,
        "hooks": [{
            "type": "command",
            "command": 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start-ontology.sh"',
        }],
    }
    duplicate = {k: v for k, v in managed_entry.items() if k != "_oma"}
    existing_hooks = {"SessionStart": [managed_entry, duplicate]}

    findings = _find_unmarked_managed_duplicates(BASE_DSL, existing_hooks, tmp_path / "x.oma.yaml")
    assert findings == [], findings


def test_malformed_hooks_json_reported_not_crashed(tmp_path):
    """A hand-corrupted hooks.json (invalid JSON, or valid JSON in the wrong
    shape) must surface as a drift line from check_drift, not an unhandled
    exception that would kill --check before it reaches the rest of the
    plugins. A real recompile (write=True), by contrast, must refuse to
    silently discard/guess at the unreadable file."""
    dsl_path = _write_plugin(tmp_path, BASE_DSL)
    compile_plugin(dsl_path, write=True)
    hooks_json_path = dsl_path.parent / "hooks" / "hooks.json"

    hooks_json_path.write_text("{ not valid json", encoding="utf-8")
    drift = check_drift([dsl_path])
    assert any("invalid JSON" in d for d in drift), drift
    with pytest.raises(CompileError, match="invalid JSON"):
        compile_plugin(dsl_path, write=True)

    hooks_json_path.write_text(json.dumps([1, 2, 3]), encoding="utf-8")
    drift = check_drift([dsl_path])
    assert any("expected a JSON object" in d for d in drift), drift

    hooks_json_path.write_text(json.dumps({"hooks": [1, 2, 3]}), encoding="utf-8")
    drift = check_drift([dsl_path])
    assert any("'hooks' key must be an object" in d for d in drift), drift


def test_check_drift_continues_after_one_plugin_fails_hard(tmp_path, monkeypatch):
    """A hard failure while checking one plugin's harness artifacts (e.g. the
    repo's canonical enforcer source going missing) must not abort drift
    reporting for the rest of the plugins passed to check_drift — a single
    broken plugin must not leave every other plugin unchecked."""
    import tools.oma_compile.compile as compile_mod

    broken_dsl_path = _write_plugin(tmp_path, POLICY_DSL)
    compile_plugin(broken_dsl_path, write=True)

    ok_dsl = {**BASE_DSL, "plugin": "z-plugin"}
    ok_dsl_path = _write_plugin(tmp_path, ok_dsl)
    compile_plugin(ok_dsl_path, write=True)

    monkeypatch.setattr(compile_mod, "HARNESS_ENFORCER_SRC", tmp_path / "does-not-exist.py")

    drift = check_drift([broken_dsl_path, ok_dsl_path])
    assert any("harness drift check failed" in d for d in drift), drift
    assert not any(str(ok_dsl_path.parent) in d for d in drift), drift


def test_malformed_harness_rules_json_reported_not_crashed(tmp_path):
    dsl_path = _write_plugin(tmp_path, POLICY_DSL)
    compile_plugin(dsl_path, write=True)
    rules_path = dsl_path.parent / "hooks" / "harness-rules.json"
    rules_path.write_text("{ not valid json", encoding="utf-8")

    drift = check_drift([dsl_path])
    assert any("harness-rules.json" in d and "invalid JSON" in d for d in drift), drift
