"""Byte-equivalence smoke test for the v0.5 plugin migrations.

Every plugin under ``plugins/`` must either:
  (a) ship a ``<plugin>.oma.yaml`` file and compile cleanly without drift, or
  (b) be intentionally skipped (not present in PLUGINS_UNDER_DSL).

The compiler's own ``check_drift`` is the ground truth — a migrated
plugin passes iff its DSL compiles to bytes equal to the committed
.mcp.json / kiro-agents/*.agent.json.
"""

from __future__ import annotations

import pytest

from tools.oma_compile.compile import REPO_ROOT, check_drift

PLUGINS_UNDER_DSL = [
    "ai-infra",
    "agenticops",
    "aidlc",
    "modernization",
]


@pytest.mark.parametrize("plugin", PLUGINS_UNDER_DSL)
def test_dsl_present_and_clean(plugin):
    dsl_path = REPO_ROOT / "plugins" / plugin / f"{plugin}.oma.yaml"
    assert dsl_path.exists(), f"{dsl_path} missing — v0.5 migration expected"

    drift = check_drift([dsl_path])
    assert drift == [], "\n".join(drift)


def test_workspace_compile_discovers_all():
    discovered = sorted(p.parent.name for p in (REPO_ROOT / "plugins").glob("*/*.oma.yaml"))
    for plugin in PLUGINS_UNDER_DSL:
        assert plugin in discovered, f"{plugin} DSL not discovered by oma-compile --all"
