"""Shared fixture helper for the harness compiler test suite.

Extracted from four near-identical `_write_plugin` copies (one each in
test_session_start_emit.py, test_stop_hook_emit.py, test_post_tool_use_emit.py,
and test_harness_drift.py) that had to move in lockstep — the same copy-drift
pattern that let some of them keep reading the pre-#71 unwrapped hooks.json
shape after only one of the four was updated for the new "hooks"-wrapped one.
"""

from __future__ import annotations

from pathlib import Path

import yaml


def write_plugin(root: Path, dsl: dict, scripts: dict[str, str] | None = None) -> Path:
    """Write a plugin dir + DSL under `root` for a compile_plugin()/check_drift()
    test.

    `scripts` maps a plugin-relative path (e.g. "hooks/stop-gate.sh") to its
    file body; omit an entry (or pass scripts=None) to exercise a hooks.<event>
    declaration whose runs script is deliberately missing.
    """
    plugin_dir = root / "plugins" / dsl["plugin"]
    (plugin_dir / "hooks").mkdir(parents=True, exist_ok=True)
    for rel_path, body in (scripts or {}).items():
        script_path = plugin_dir / rel_path
        script_path.parent.mkdir(parents=True, exist_ok=True)
        script_path.write_text(body, encoding="utf-8")
    out = plugin_dir / f"{dsl['plugin']}.oma.yaml"
    out.write_text(yaml.safe_dump(dsl, sort_keys=False), encoding="utf-8")
    return out
