#!/usr/bin/env python3
"""Standalone harness verification — runs without pytest/pip/opa.

Why: this dev environment has no pytest, no pip, and no opa binary. Ralph still
needs fresh evidence per acceptance criterion, so this runner exercises the
enforcer, the compiler, and the compiled plugin artifacts directly and prints a
PASS/FAIL line per check. Exit 0 iff every check passes.

Run: python3 tests/standalone/run_harness_checks.py
"""
from __future__ import annotations

import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ENFORCER = REPO / "tools" / "oma_harness" / "enforce.py"

# Make the repo root importable (no installed package; no pytest rootdir).
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

_results: list[tuple[bool, str]] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    _results.append((cond, name))
    mark = "PASS" if cond else "FAIL"
    line = f"[{mark}] {name}"
    if detail and not cond:
        line += f"  -- {detail}"
    print(line)


def _load_enforcer():
    spec = importlib.util.spec_from_file_location("oma_enforce", ENFORCER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _decide(rules_path: str, event: dict) -> dict:
    """Invoke enforce.py as a subprocess (true hook contract) and parse stdout."""
    proc = subprocess.run(
        [sys.executable, str(ENFORCER)],
        input=json.dumps(event),
        capture_output=True,
        text=True,
        env={**os.environ, "OMA_HARNESS_RULES": rules_path},
    )
    try:
        return json.loads(proc.stdout)["hookSpecificOutput"]
    except Exception:
        return {"_raw": proc.stdout, "_err": proc.stderr, "_rc": proc.returncode}


PLUGIN_ROOT = REPO / "plugins" / "ai-infra"


def _decide_via_plugin(event: dict, rules_env: str | None = None) -> dict:
    """Run the plugin's bundled enforce.py the way Claude Code would: with
    CLAUDE_PLUGIN_ROOT set so it loads hooks/harness-rules.json. Pass rules_env
    to point at an explicit ruleset instead (used for the corrupt-file case)."""
    env = {k: v for k, v in os.environ.items()
           if k not in ("OMA_HARNESS_RULES", "CLAUDE_PLUGIN_ROOT")}
    if rules_env:
        env["OMA_HARNESS_RULES"] = rules_env
    else:
        env["CLAUDE_PLUGIN_ROOT"] = str(PLUGIN_ROOT)
    proc = subprocess.run(
        [sys.executable, str(PLUGIN_ROOT / "hooks" / "enforce.py")],
        input=json.dumps(event), capture_output=True, text=True, env=env,
    )
    try:
        return json.loads(proc.stdout)["hookSpecificOutput"]
    except Exception:
        return {"_raw": proc.stdout, "_err": proc.stderr}


def test_enforcer_decisions() -> None:
    rules = {
        "rules": [
            {"id": "deny-kubectl-mutate", "tool": "Bash",
             "deny_if": {"command_matches": r"kubectl\s+(apply|delete|patch)"},
             "decision": "deny", "reason": "blocked"},
            {"id": "deny-secret-write", "tool": "Write",
             "deny_if": {"file_path_matches": r"(^|/)\.env(\.|$)|secrets?/"},
             "decision": "deny", "reason": "blocked"},
        ]
    }
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        json.dump(rules, fh)
        rpath = fh.name

    d = _decide(rpath, {"tool_name": "Bash", "tool_input": {"command": "kubectl apply -f x.yaml"}})
    check("US-001 kubectl apply -> deny", d.get("permissionDecision") == "deny", str(d))

    d = _decide(rpath, {"tool_name": "Bash", "tool_input": {"command": "kubectl get pods"}})
    check("US-001 kubectl get -> allow", d.get("permissionDecision") == "allow", str(d))

    d = _decide(rpath, {"tool_name": "Write", "tool_input": {"file_path": "config/.env"}})
    check("US-001 Write .env -> deny", d.get("permissionDecision") == "deny", str(d))

    d = _decide(rpath, {"tool_name": "Write", "tool_input": {"file_path": "README.md"}})
    check("US-001 Write README -> allow", d.get("permissionDecision") == "allow", str(d))

    os.unlink(rpath)


def test_enforcer_edge_cases() -> None:
    # no ruleset -> allow
    proc = subprocess.run(
        [sys.executable, str(ENFORCER)],
        input=json.dumps({"tool_name": "Bash", "tool_input": {"command": "kubectl apply -f x"}}),
        capture_output=True, text=True,
        env={k: v for k, v in os.environ.items()
             if k not in ("OMA_HARNESS_RULES", "CLAUDE_PLUGIN_ROOT")},
    )
    try:
        d = json.loads(proc.stdout)["hookSpecificOutput"]
    except Exception:
        d = {}
    check("US-001 no ruleset -> allow", d.get("permissionDecision") == "allow", str(proc.stdout))

    # malformed regex in one rule must not block the good rule
    bad = {"rules": [
        {"id": "bad", "tool": "Bash", "deny_if": {"command_matches": "(unclosed"}, "reason": "x"},
        {"id": "good", "tool": "Bash", "deny_if": {"command_matches": "rm -rf"}, "reason": "blocked rm"},
    ]}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        json.dump(bad, fh)
        rpath = fh.name
    d = _decide(rpath, {"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}})
    check("US-001 bad regex skipped, good rule fires", d.get("permissionDecision") == "deny", str(d))
    os.unlink(rpath)


def test_schema_us002() -> None:
    schema = json.loads((REPO / "schemas" / "harness" / "dsl.schema.json").read_text())
    blob = json.dumps(schema)
    pr = schema["definitions"]["policyRef"]
    check("US-002 policyRef requires id+enforce",
          set(pr.get("required", [])) == {"id", "enforce"}, str(pr.get("required")))
    check("US-002 no rego_ref anywhere in schema", "rego_ref" not in blob)
    deny_if = pr["properties"]["enforce"]["properties"]["deny_if"]["properties"]
    check("US-002 deny_if has all 4 condition keys",
          {"command_matches", "command_matches_any", "file_path_matches", "input_field"} <= set(deny_if),
          str(list(deny_if)))
    check("US-002 deny_if minProperties:1",
          pr["properties"]["enforce"]["properties"]["deny_if"].get("minProperties") == 1)
    # ai-infra DSL validates against the new schema
    from tools.oma_compile.compile import _load_dsl, _validate, REPO_ROOT
    dsl = _load_dsl(REPO_ROOT / "plugins" / "ai-infra" / "ai-infra.oma.yaml")
    try:
        _validate(dsl, REPO_ROOT / "plugins" / "ai-infra" / "ai-infra.oma.yaml")
        check("US-002 ai-infra DSL validates", True)
    except Exception as e:
        check("US-002 ai-infra DSL validates", False, str(e)[:200])


def test_compile_us003() -> None:
    from tools.oma_compile.compile import compile_plugin, REPO_ROOT, CompileError, _load_dsl
    dsl_path = REPO_ROOT / "plugins" / "ai-infra" / "ai-infra.oma.yaml"
    compile_plugin(dsl_path, write=True)
    hooks_dir = REPO_ROOT / "plugins" / "ai-infra" / "hooks"
    check("US-003 enforce.py bundled", (hooks_dir / "enforce.py").exists())
    check("US-003 harness-rules.json bundled", (hooks_dir / "harness-rules.json").exists())
    hooks_json = json.loads((hooks_dir / "hooks.json").read_text())
    cmd = hooks_json["PreToolUse"][0]["hooks"][0]["command"]
    check("US-003 hooks.json refs CLAUDE_PLUGIN_ROOT/hooks/enforce.py",
          "${CLAUDE_PLUGIN_ROOT}/hooks/enforce.py" in cmd, cmd)
    rules = json.loads((hooks_dir / "harness-rules.json").read_text())
    dsl = _load_dsl(dsl_path)
    dsl_ids = {p["id"] for p in dsl["policies"]}
    rule_ids = {r["id"] for r in rules["rules"]}
    check("US-003 rules match DSL policy ids", dsl_ids == rule_ids, f"{dsl_ids} vs {rule_ids}")
    # invalid regex -> CompileError
    import copy, tempfile, yaml as _yaml
    bad = copy.deepcopy(dsl)
    bad["policies"][0]["enforce"]["deny_if"]["command_matches"] = "(unclosed"
    with tempfile.TemporaryDirectory() as td:
        # write into the same plugin dir tree so relative hook refs resolve
        bad_path = hooks_dir.parent / "_bad_test.oma.yaml"
        bad_path.write_text(_yaml.safe_dump(bad))
        try:
            compile_plugin(bad_path, write=False)
            check("US-003 invalid regex fails compile", False, "no CompileError raised")
        except CompileError:
            check("US-003 invalid regex fails compile", True)
        finally:
            bad_path.unlink()
    # no rego/opa in compile.py
    comp_src = (REPO / "tools" / "oma_compile" / "compile.py").read_text().lower()
    check("US-003 compile.py has no rego_ref/opa",
          "rego_ref" not in comp_src and "opa" not in comp_src,
          "found rego_ref or opa in compile.py")


def test_opa_purge_us004() -> None:
    rego = list(REPO.glob("policies/**/*.rego"))
    check("US-004 no .rego files remain", not rego, str(rego))
    vsh = (REPO / "scripts" / "oma" / "validate.sh")
    if vsh.exists():
        check("US-004 validate.sh no opa shell-out", "opa eval" not in vsh.read_text())
    else:
        check("US-004 validate.sh no opa shell-out", True, "validate.sh removed")
    check("US-004 test_opa_stub.py gone or rewritten",
          not (REPO / "tests" / "harness" / "test_opa_stub.py").exists()
          or "opa" not in (REPO / "tests" / "harness" / "test_opa_stub.py").read_text().lower())
    # Functional refs only: an actual opa invocation or a rego_ref field/key.
    # Prose like "no external policy engine (no OPA)" is allowed — what matters
    # is that nothing CALLS opa or reads a rego_ref anymore.
    out = subprocess.run(
        ["grep", "-rnE",
         "--exclude=run_harness_checks.py",  # this checker names the patterns it forbids
         r"opa[ _](eval|run|test)|rego_ref|['\"]rego['\"]|import opa|subprocess.*opa",
         "tools", "scripts", "schemas", "tests"],
        cwd=str(REPO), capture_output=True, text=True,
    )
    hits = [h for h in out.stdout.strip().splitlines() if h]
    check("US-004 no functional opa/rego refs in code/scripts/schemas/tests",
          not hits, f"hits: {hits}")


def test_e2e_us005() -> None:
    # Simulate the compiled plugin's hook chain via the shared helper.
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "kubectl apply -f deploy.yaml"}})
    check("US-005 e2e kubectl apply -> deny", d.get("permissionDecision") == "deny", str(d))
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "kubectl get pods -A"}})
    check("US-005 e2e kubectl get -> allow", d.get("permissionDecision") == "allow", str(d))
    # oma compile --check clean
    proc = subprocess.run([sys.executable, "-m", "tools.oma_compile", "--check"],
                          cwd=str(REPO), capture_output=True, text=True)
    check("US-005 oma compile --check clean", proc.returncode == 0,
          (proc.stdout + proc.stderr)[:300])


def test_hardening() -> None:
    """Post-review hardening: bypass closures + fail-closed on corrupt ruleset.
    Runs against the compiled ai-infra ruleset via _decide_via_plugin."""
    # Edit-bypass closed
    d = _decide_via_plugin({"tool_name": "Edit", "tool_input": {"file_path": "config/.env"}})
    check("HARDEN Edit .env -> deny", d.get("permissionDecision") == "deny", str(d))
    # Bash redirect bypass closed
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "echo SECRET=x > .env"}})
    check("HARDEN Bash > .env -> deny", d.get("permissionDecision") == "deny", str(d))
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "cat k | tee secrets/app.key"}})
    check("HARDEN Bash tee secrets/ -> deny", d.get("permissionDecision") == "deny", str(d))
    # kubectl verb coverage
    for verb in ("create deployment x", "exec pod -- rm -rf /", "rollout restart deploy/x", "set image deand"):
        d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": f"kubectl {verb}"}})
        check(f"HARDEN kubectl {verb.split()[0]} -> deny", d.get("permissionDecision") == "deny", str(d))
    # still allow reads
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "kubectl get pods"}})
    check("HARDEN kubectl get still allow", d.get("permissionDecision") == "allow", str(d))
    d = _decide_via_plugin({"tool_name": "Edit", "tool_input": {"file_path": "README.md"}})
    check("HARDEN Edit README still allow", d.get("permissionDecision") == "allow", str(d))
    # corrupt ruleset -> fail closed (ask)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
        fh.write("{ this is not valid json ")
        bad = fh.name
    d = _decide_via_plugin({"tool_name": "Bash", "tool_input": {"command": "echo hi"}}, rules_env=bad)
    check("HARDEN corrupt ruleset -> ask (fail-closed)", d.get("permissionDecision") == "ask", str(d))
    os.unlink(bad)


def main() -> int:
    test_enforcer_decisions()
    test_enforcer_edge_cases()
    test_schema_us002()
    test_compile_us003()
    test_opa_purge_us004()
    test_e2e_us005()
    test_hardening()
    failed = [n for ok, n in _results if not ok]
    print(f"\n{len(_results) - len(failed)}/{len(_results)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
