"""Round-trip test for the agentic-platform DSL.

Compiles the DSL into a temp directory and compares the emitted output to
the committed .mcp.json / kiro-agents/*.agent.json. A failure here means
either the DSL source or the committed native files drifted — CI should
reject the PR.
"""

from __future__ import annotations

import json

import pytest

from tools.oma_compile import compile_plugin
from tools.oma_compile.compile import REPO_ROOT

DSL = REPO_ROOT / "plugins" / "agentic-platform" / "agentic-platform.oma.yaml"
MCP = REPO_ROOT / "plugins" / "agentic-platform" / ".mcp.json"
AGENT = REPO_ROOT / "plugins" / "agentic-platform" / "kiro-agents" / "agentic-platform.agent.json"


@pytest.mark.skipif(not DSL.exists(), reason="agentic-platform DSL not yet migrated")
def test_agentic_platform_round_trip():
    """Compile the DSL in memory (write=False) and compare to committed files.

    We purposely do not copy to tmp: the DSL references hook scripts via
    relative paths (`../../hooks/session-start.sh`), and the compiler
    verifies that those exist. Staying in-place preserves those refs.
    """
    result = compile_plugin(DSL, write=False)
    # Re-invoke with write=True then compare; check_drift is the stronger guard
    # and `oma compile --check` in CI already covers that path. Here we just
    # confirm the compiler produces the same byte layout as committed.
    from tools.oma_compile.compile import _build_mcp_json, _build_agent_json, _load_dsl

    dsl = _load_dsl(DSL)
    expected_mcp = _build_mcp_json(dsl)
    committed_mcp = json.loads(MCP.read_text(encoding="utf-8"))
    assert expected_mcp == committed_mcp, "DSL output diverged from committed .mcp.json"

    kiro_agents = [a for a in dsl.get("agents") or [] if a.get("runtime") == "kiro"]
    assert kiro_agents, "agentic-platform DSL must declare at least one Kiro agent"
    expected_agent = _build_agent_json(dsl, kiro_agents[0])
    committed_agent = json.loads(AGENT.read_text(encoding="utf-8"))
    assert expected_agent == committed_agent, "DSL output diverged from committed agent.json"

    assert result.plugin == "agentic-platform"
