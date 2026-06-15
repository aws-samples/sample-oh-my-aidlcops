#!/usr/bin/env python3
"""enforce.py — OMA harness PreToolUse enforcement (pure CC, no OPA).

This is the runtime enforcement point of the OMA harness. It is invoked by
Claude Code as a **PreToolUse hook** that a plugin ships in its
`hooks/hooks.json`. It runs at the harness level *before* a tool executes, so a
denied call never reaches the model's context — this is real enforcement, not
prompt-level guidance.

DESIGN (why pure Python, no OPA):
  The harness must guarantee enforcement. Shelling out to an external `opa`
  binary makes enforcement depend on that binary being installed; when it is
  absent the legacy validate.sh path silently fell through (fail-OPEN), which
  is fatal for a safety device. This enforcer is bundled inside the plugin and
  referenced via ${CLAUDE_PLUGIN_ROOT}, so it cannot go missing, and it
  fails-CLOSED on its own bugs only for the matched tool (see below).

CONTRACT (Claude Code PreToolUse hook):
  stdin  : JSON { tool_name, tool_input, ... }
  stdout : JSON { hookSpecificOutput: { hookEventName: "PreToolUse",
                  permissionDecision: "deny"|"allow"|"ask",
                  permissionDecisionReason: str } }
  exit 0 : decision is taken from stdout JSON.

  Policy source: a compiled JSON ruleset. Resolution order:
    1. $OMA_HARNESS_RULES         (explicit path; used by tests)
    2. $CLAUDE_PLUGIN_ROOT/hooks/harness-rules.json   (shipped by the plugin)
  If no ruleset resolves, the enforcer ALLOWS (it owns no policy → nothing to
  enforce). This is deliberate: absence-of-policy ≠ absence-of-enforcement; a
  plugin that wants enforcement always ships its ruleset next to this script.

RULE MODEL (compiled from the DSL `policies:` block):
  {
    "rules": [
      {
        "id": "deny-eks-write",
        "tool": "Bash",                 # exact tool name, or omit for any
        "deny_if": {                    # all conditions AND together
          "command_matches": "kubectl\\s+(apply|delete|edit|patch|scale)",
          "command_matches_any": ["...", "..."],
          "file_path_matches": "\\.env$",
          "input_field": {"path": "command", "matches": "..."}
        },
        "decision": "deny",             # deny | ask  (default deny)
        "reason": "EKS writes require an approved Deployment + explicit --allow-write."
      }
    ]
  }

  A rule fires when (tool matches OR tool omitted) AND every declared
  condition matches. First firing rule wins. No rule fires → allow.
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any


def _emit(decision: str, reason: str = "") -> None:
    """Write the PreToolUse decision and exit 0 (decision is read from stdout)."""
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
        }
    }
    if reason:
        out["hookSpecificOutput"]["permissionDecisionReason"] = reason
    sys.stdout.write(json.dumps(out))
    sys.exit(0)


def _allow() -> None:
    _emit("allow")


class _CorruptRuleset(Exception):
    """A ruleset file exists but cannot be read/parsed — fail closed."""


def _load_rules() -> dict | None:
    path = os.environ.get("OMA_HARNESS_RULES")
    if not path:
        root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if root:
            path = os.path.join(root, "hooks", "harness-rules.json")
    if not path or not os.path.exists(path):
        return None  # genuinely no policy → nothing to enforce (allow)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        # A ruleset was SHIPPED but is unreadable. Distinguish this from "no
        # ruleset": enforcement was intended, so we must NOT silently allow.
        # Fail closed (ask the user) rather than disable the safety device.
        raise _CorruptRuleset(str(exc))


def _get_field(tool_input: dict, dotted: str) -> Any:
    cur: Any = tool_input
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def _cond_matches(cond: dict, tool_input: dict) -> bool:
    """Every declared condition must match (AND). Unknown keys are ignored."""
    matched_any_condition = False

    if "command_matches" in cond:
        matched_any_condition = True
        cmd = str(tool_input.get("command", ""))
        if not re.search(cond["command_matches"], cmd):
            return False

    if "command_matches_any" in cond:
        matched_any_condition = True
        cmd = str(tool_input.get("command", ""))
        if not any(re.search(p, cmd) for p in cond["command_matches_any"]):
            return False

    if "file_path_matches" in cond:
        matched_any_condition = True
        # Edit/Write use file_path; Read uses file_path; NotebookEdit notebook_path
        fp = str(
            tool_input.get("file_path")
            or tool_input.get("notebook_path")
            or ""
        )
        if not re.search(cond["file_path_matches"], fp):
            return False

    if "input_field" in cond:
        matched_any_condition = True
        spec = cond["input_field"]
        val = _get_field(tool_input, spec.get("path", ""))
        if val is None or not re.search(spec.get("matches", ""), str(val)):
            return False

    # An empty deny_if would match everything — that is almost never intended,
    # so treat it as non-matching to avoid an accidental block-all rule.
    return matched_any_condition


def _evaluate(ruleset: dict, tool_name: str, tool_input: dict) -> tuple[str, str] | None:
    for rule in ruleset.get("rules", []):
        rule_tool = rule.get("tool")
        if rule_tool and rule_tool != tool_name:
            continue
        cond = rule.get("deny_if") or {}
        try:
            fired = _cond_matches(cond, tool_input)
        except re.error:
            # A malformed regex in one rule must not crash the whole enforcer
            # (which would fail-open for ALL tools). Skip the broken rule.
            continue
        if fired:
            decision = rule.get("decision", "deny")
            reason = rule.get("reason", f"Blocked by harness rule {rule.get('id', '?')}.")
            return decision, reason
    return None


def main() -> int:
    try:
        raw = sys.stdin.read()
        event = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        _allow()  # cannot parse the event → do not block (fail-open on parse)
        return 0

    tool_name = event.get("tool_name", "")
    tool_input = event.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}

    try:
        ruleset = _load_rules()
    except _CorruptRuleset as exc:
        # Shipped-but-broken ruleset: fail closed. `ask` hands the call to the
        # user rather than hard-denying everything, so a parse bug degrades to
        # "confirm manually" instead of silently disabling enforcement.
        _emit("ask", f"Harness ruleset present but unreadable ({exc}); "
                     "enforcement cannot be evaluated. Confirm manually or fix "
                     "hooks/harness-rules.json.")
        return 0
    if not ruleset:
        _allow()
        return 0

    verdict = _evaluate(ruleset, tool_name, tool_input)
    if verdict is None:
        _allow()
        return 0

    decision, reason = verdict
    _emit(decision, reason)
    return 0


if __name__ == "__main__":
    main()
