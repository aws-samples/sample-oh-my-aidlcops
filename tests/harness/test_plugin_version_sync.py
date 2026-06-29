"""Version-skew guard for the plugin marketplace.

Claude Code resolves a plugin's version from ``plugin.json`` first and only
falls back to the marketplace entry when ``plugin.json`` omits it. So when the
two disagree, ``/plugin list`` and ``/plugin update`` honour ``plugin.json``
and the marketplace number is silently ignored. That is exactly the skew that
shipped 0.1.0 to users while the marketplace, tag, and docs all claimed
0.4.0-preview.1 (issue #58).

This test fails the build whenever any plugin's ``plugin.json`` version drifts
from its ``marketplace.json`` entry, so the two can never diverge again without
CI catching it.
"""

from __future__ import annotations

import json

from tools.oma_compile.compile import REPO_ROOT

MARKETPLACE = REPO_ROOT / ".claude-plugin" / "marketplace.json"


def _marketplace() -> dict:
    return json.loads(MARKETPLACE.read_text(encoding="utf-8"))


def _plugin_json(name: str) -> dict:
    path = REPO_ROOT / "plugins" / name / ".claude-plugin" / "plugin.json"
    return json.loads(path.read_text(encoding="utf-8"))


def test_plugin_json_matches_marketplace_entry():
    """Every plugin.json version equals its marketplace.json entry version.

    plugin.json wins at resolution time, so a mismatch means users see the
    plugin.json number regardless of what the marketplace advertises.
    """
    market = _marketplace()
    mismatches = []
    for entry in market["plugins"]:
        name = entry["name"]
        market_ver = entry.get("version")
        plugin_ver = _plugin_json(name).get("version")
        if market_ver != plugin_ver:
            mismatches.append(
                f"{name}: plugin.json={plugin_ver!r} != marketplace.json={market_ver!r}"
            )
    assert not mismatches, (
        "plugin.json wins over marketplace.json at resolution time, so these "
        "plugins would show the wrong version in `/plugin list`:\n  "
        + "\n  ".join(mismatches)
    )


def test_all_plugin_versions_are_uniform():
    """All four plugins ship the same version as the top-level marketplace.

    OMA releases the marketplace as one unit, so a per-plugin version split
    is always a mistake during the tech-preview line.
    """
    market = _marketplace()
    top_level = market["metadata"]["version"]
    offenders = [
        entry["name"]
        for entry in market["plugins"]
        if _plugin_json(entry["name"]).get("version") != top_level
    ]
    assert not offenders, (
        f"these plugins do not match the marketplace version {top_level!r}: "
        f"{offenders}"
    )
