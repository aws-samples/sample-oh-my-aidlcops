"""DSL -> native files compiler.

Emits two files per plugin:
  - <plugin>/.mcp.json                            (Claude Code)
  - <plugin>/kiro-agents/<agent>.agent.json       (Kiro; only when runtime=kiro
                                                   agents are present)

And one workspace-level merge:
  - .omao/triggers.json                           (all triggers across plugins)

Hooks are declared-only. The compiler verifies that `hooks.<event>.runs`
points at an existing file under the plugin, but does not codegen shell
scripts — those stay hand-authored.
"""

from __future__ import annotations

import json
import re
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import yaml

# jsonschema>=4.18 deprecated RefResolver. Migration to referencing.Registry
# is planned; silence the warning at import time so CI runs with -W error stay
# green.
warnings.filterwarnings(
    "ignore",
    category=DeprecationWarning,
    module=r"jsonschema(\..*)?",
)

from jsonschema import Draft7Validator, RefResolver

REPO_ROOT = Path(__file__).resolve().parents[2]
DSL_SCHEMA_PATH = REPO_ROOT / "schemas" / "harness" / "dsl.schema.json"
ONTOLOGY_SCHEMA_DIR = REPO_ROOT / "schemas" / "ontology"
TRIGGERS_OUT = REPO_ROOT / ".omao" / "triggers.json"


def _build_ref_store() -> dict:
    """Build a local $ref store so Draft7Validator never performs network I/O."""
    store: dict = {}
    if ONTOLOGY_SCHEMA_DIR.exists():
        for schema_path in ONTOLOGY_SCHEMA_DIR.glob("*.schema.json"):
            content = json.loads(schema_path.read_text(encoding="utf-8"))
            store[content["$id"]] = content
            store[f"../ontology/{schema_path.name}"] = content
    if DSL_SCHEMA_PATH.exists():
        dsl_content = json.loads(DSL_SCHEMA_PATH.read_text(encoding="utf-8"))
        store[dsl_content["$id"]] = dsl_content
    return store

PINNED_VERSION_RE = re.compile(r"==\d+\.\d+\.\d+")


class CompileError(RuntimeError):
    """Raised when a *.oma.yaml is invalid or references missing assets."""


@dataclass
class CompileResult:
    plugin: str
    mcp_json_path: Path
    agent_json_paths: list[Path]
    triggers: list[dict]


def _load_schema() -> dict:
    with DSL_SCHEMA_PATH.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _load_dsl(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh)
    if not isinstance(data, dict):
        raise CompileError(f"{path}: top-level must be a mapping")
    return data


def _validate(dsl: dict, source: Path) -> None:
    schema = _load_schema()
    resolver = RefResolver.from_schema(schema, store=_build_ref_store())
    validator = Draft7Validator(schema, resolver=resolver)
    errors = sorted(validator.iter_errors(dsl), key=lambda e: list(e.absolute_path))
    if errors:
        details = "\n".join(f"  - {list(e.absolute_path)}: {e.message}" for e in errors)
        raise CompileError(f"{source}: DSL schema violations\n{details}")

    mcp_ids = set((dsl.get("mcp") or {}).keys())
    for agent in dsl.get("agents") or []:
        for ref in agent.get("mcp") or []:
            if ref not in mcp_ids:
                raise CompileError(
                    f"{source}: agent {agent['id']!r} references undeclared MCP id {ref!r}"
                )
    for name, server in (dsl.get("mcp") or {}).items():
        args = server.get("args") or []
        if not any(PINNED_VERSION_RE.search(a) for a in args):
            raise CompileError(
                f"{source}: mcp {name!r} has no pinned version (expected '==X.Y.Z' in args)"
            )

    # v2-only checks: the schema already rejects the fields on v1, we just
    # need to keep the v1 file untouched here.
    if dsl.get("version") == 2:
        _validate_workflows(dsl, source)
        _verify_rego_refs(dsl, source)


def _verify_rego_refs(dsl: dict, source: Path) -> None:
    """Verify every policies[].rego_ref points at an existing .rego file."""
    for policy in dsl.get("policies") or []:
        rel = policy.get("rego_ref")
        if not rel:
            continue
        candidate = (REPO_ROOT / rel).resolve()
        if not candidate.exists():
            raise CompileError(
                f"{source}: policy {policy['id']!r} rego_ref points at missing file {rel!r}"
            )


def _validate_workflows(dsl: dict, source: Path) -> None:
    """Validate v2 workflow DAGs: step refs resolve, depends_on is a DAG."""
    workflows = dsl.get("workflows") or {}
    agent_ids = {a["id"] for a in (dsl.get("agents") or [])}
    for wf_name, workflow in workflows.items():
        steps = workflow.get("steps") or []
        step_ids = set()
        for step in steps:
            sid = step["id"]
            if sid in step_ids:
                raise CompileError(
                    f"{source}: workflow {wf_name!r} has duplicate step id {sid!r}"
                )
            step_ids.add(sid)
            if "agent_ref" in step and step["agent_ref"] not in agent_ids:
                raise CompileError(
                    f"{source}: workflow {wf_name!r} step {sid!r} references "
                    f"undeclared agent_ref {step['agent_ref']!r}"
                )
            # skill_ref is resolved by the harness at runtime, not here.
        # depends_on must stay within the same workflow.
        for step in steps:
            for dep in step.get("depends_on") or []:
                if dep not in step_ids:
                    raise CompileError(
                        f"{source}: workflow {wf_name!r} step {step['id']!r} "
                        f"depends_on {dep!r} which is not declared in the same workflow"
                    )
        # Cycle detection (Kahn's algorithm).
        indeg = {sid: 0 for sid in step_ids}
        edges: dict[str, list[str]] = {sid: [] for sid in step_ids}
        for step in steps:
            for dep in step.get("depends_on") or []:
                edges[dep].append(step["id"])
                indeg[step["id"]] += 1
        queue = [sid for sid, deg in indeg.items() if deg == 0]
        visited = 0
        while queue:
            sid = queue.pop()
            visited += 1
            for succ in edges[sid]:
                indeg[succ] -= 1
                if indeg[succ] == 0:
                    queue.append(succ)
        if visited != len(step_ids):
            raise CompileError(
                f"{source}: workflow {wf_name!r} depends_on graph has a cycle"
            )


def _build_mcp_json(dsl: dict) -> dict:
    servers: dict[str, dict] = {}
    for short_id, spec in (dsl.get("mcp") or {}).items():
        servers[short_id] = {
            "type": spec.get("type", "stdio"),
            "command": spec["command"],
            "args": list(spec["args"]),
            "env": dict(spec.get("env") or {}),
            "timeout": spec.get("timeout", 120000),
        }
    return {
        "$schema": "../../schemas/mcp.schema.json",
        "mcpServers": servers,
    }


def _build_agent_json(dsl: dict, agent: dict) -> dict:
    mcp_servers: dict[str, dict] = {}
    dsl_mcp = dsl.get("mcp") or {}
    env_overrides = agent.get("mcpEnvOverrides") or {}
    for short_id in agent.get("mcp") or []:
        spec = dsl_mcp[short_id]
        env = dict(spec.get("env") or {})
        env.update(env_overrides.get(short_id) or {})
        mcp_servers[f"awslabs.{short_id}-mcp-server"] = {
            "command": spec["command"],
            "args": list(spec["args"]),
            "env": env,
            "disabled": False,
        }
    out: dict = {
        "name": agent["id"],
        "description": agent.get("description", ""),
        "tools": agent.get("tools") or ["*"],
        "mcpServers": mcp_servers,
        "autoApprove": {
            "readOnly": True,
            "fileWrites": False,
            "bashCommands": False,
        },
    }
    if agent.get("resources"):
        out["resources"] = list(agent["resources"])
    if agent.get("welcomeMessage"):
        out["welcomeMessage"] = agent["welcomeMessage"]
    if agent.get("notes"):
        out["_meta"] = agent["notes"]
    return out


def _verify_hooks(dsl: dict, plugin_dir: Path, source: Path) -> None:
    for event, spec in (dsl.get("hooks") or {}).items():
        runs = spec.get("runs")
        if not runs:
            continue
        candidate = (plugin_dir / runs).resolve()
        if not candidate.exists():
            raise CompileError(
                f"{source}: hook {event!r} points at missing script {runs!r}"
            )


def compile_plugin(dsl_path: Path, write: bool = True) -> CompileResult:
    dsl_path = dsl_path.resolve()
    plugin_dir = dsl_path.parent
    dsl = _load_dsl(dsl_path)
    _validate(dsl, dsl_path)
    _verify_hooks(dsl, plugin_dir, dsl_path)

    mcp_path = plugin_dir / ".mcp.json"
    mcp_payload = _build_mcp_json(dsl)

    kiro_dir = plugin_dir / "kiro-agents"
    agent_json_paths: list[Path] = []
    kiro_payloads: list[tuple[Path, dict]] = []
    for agent in dsl.get("agents") or []:
        if agent.get("runtime") != "kiro":
            continue
        agent_path = kiro_dir / f"{agent['id']}.agent.json"
        kiro_payloads.append((agent_path, _build_agent_json(dsl, agent)))
        agent_json_paths.append(agent_path)

    triggers = []
    for t in (dsl.get("triggers") or []):
        entry = {
            "id": t["id"],
            "keywords": list(t["keywords"]),
            "command": t["command"],
            "plugin": dsl["plugin"],
        }
        if t.get("context_required"):
            entry["context_required"] = list(t["context_required"])
        else:
            entry["context_required"] = []
        entry["description"] = t.get("description", "")
        triggers.append(entry)

    if write:
        mcp_path.parent.mkdir(parents=True, exist_ok=True)
        _write_json(mcp_path, mcp_payload)
        for agent_path, payload in kiro_payloads:
            agent_path.parent.mkdir(parents=True, exist_ok=True)
            _write_json(agent_path, payload)

    return CompileResult(
        plugin=dsl["plugin"],
        mcp_json_path=mcp_path,
        agent_json_paths=agent_json_paths,
        triggers=triggers,
    )


def _write_json(path: Path, payload: dict) -> None:
    serialized = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    path.write_text(serialized, encoding="utf-8")


def compile_workspace(plugin_files: Iterable[Path], write: bool = True) -> list[CompileResult]:
    results: list[CompileResult] = []
    all_triggers: list[dict] = []
    for dsl_path in plugin_files:
        result = compile_plugin(dsl_path, write=write)
        results.append(result)
        all_triggers.extend(result.triggers)
    if write and all_triggers:
        TRIGGERS_OUT.parent.mkdir(parents=True, exist_ok=True)
        _write_json(TRIGGERS_OUT, {"triggers": all_triggers})
    return results


def enforce_strict_enterprise(plugin_files: Iterable[Path]) -> list[str]:
    """Apply enterprise gates that are too strict for the default compile path.

    Rules enforced:
      * Every plugin DSL must be version 2.
      * No plugin DSL may be missing.
      * Every on-disk Deployment ontology instance with
        approval_state=approved must carry a non-empty approval_chain.
      * Every on-disk Deployment with an object-form artifact must include
        a ``sha256:...`` digest.
      * Every Risk must carry either owasp_llm_top10_id or
        nist_ai_rmf_subcategory.

    Returns a list of per-entity error lines. Empty list == gate OK.
    """
    errors: list[str] = []

    for dsl_path in plugin_files:
        dsl = _load_dsl(dsl_path)
        if dsl.get("version") != 2:
            errors.append(
                ERR_V1_REJECTED.format(
                    path=dsl_path.relative_to(REPO_ROOT),
                    version=dsl.get("version")
                )
            )

    deploy_dir = REPO_ROOT / ".omao" / "ontology" / "deployments"
    if deploy_dir.is_dir():
        for dep_file in sorted(deploy_dir.glob("*.json")):
            try:
                doc = json.loads(dep_file.read_text(encoding="utf-8"))
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{dep_file.name}: cannot parse ({exc})")
                continue
            dep_id = doc.get("id") or dep_file.stem
            if doc.get("approval_state") == "approved" and not (
                doc.get("approval_chain") or []
            ):
                errors.append(ERR_APPROVAL_CHAIN_EMPTY.format(dep_id=dep_id))
            artifact = doc.get("artifact")
            if isinstance(artifact, dict):
                digest = artifact.get("digest", "")
                if not PINNED_VERSION_RE.search("") and not _SHA256.match(digest):
                    errors.append(
                        ERR_ARTIFACT_DIGEST.format(dep_id=dep_id, digest=digest)
                    )
            elif isinstance(artifact, str):
                errors.append(ERR_ARTIFACT_LEGACY_STRING.format(dep_id=dep_id))

    risk_dir = REPO_ROOT / ".omao" / "ontology" / "risks"
    if risk_dir.is_dir():
        for risk_file in sorted(risk_dir.glob("*.json")):
            try:
                doc = json.loads(risk_file.read_text(encoding="utf-8"))
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{risk_file.name}: cannot parse ({exc})")
                continue
            risk_id = doc.get("id") or risk_file.stem
            if not (doc.get("owasp_llm_top10_id") or doc.get("nist_ai_rmf_subcategory")):
                errors.append(ERR_RISK_MISSING_CLASSIFICATION.format(risk_id=risk_id))
    return errors


_SHA256 = re.compile(r"^sha256:[a-f0-9]{64}$")

# Strict-enterprise error message templates.
# These are user-visible strings that downstream scripts may grep/alert on.
# If you need to change the wording, update tests/harness/test_strict_enterprise_snapshots.py
# in the same commit and bump SNAPSHOT_VERSION.
ERR_V1_REJECTED = (
    "{path}: strict-enterprise requires version: 2 (found version={version}). "
    "Fix: bump `version: 1` to `version: 2` in the DSL."
)
ERR_APPROVAL_CHAIN_EMPTY = (
    "deployment {dep_id!r}: approval_state=approved but approval_chain "
    "is empty. Fix: append one approval link with approver/approved_at/reason."
)
ERR_ARTIFACT_DIGEST = (
    "deployment {dep_id!r}: artifact.digest missing or malformed "
    "(got {digest!r}). Fix: provide sha256:<64 hex>."
)
ERR_ARTIFACT_LEGACY_STRING = (
    "deployment {dep_id!r}: legacy string artifact is rejected under "
    "strict-enterprise. Fix: replace with the object form (uri/digest)."
)
ERR_RISK_MISSING_CLASSIFICATION = (
    "risk {risk_id!r}: strict-enterprise requires at least one of "
    "owasp_llm_top10_id (LLM01..LLM10) or nist_ai_rmf_subcategory "
    "(e.g. MEASURE.2.6). Fix: add the classification that best matches "
    "this risk."
)


def check_drift(plugin_files: Iterable[Path]) -> list[str]:
    """Compare what the compiler would emit to what is on disk.

    Returns list of human-readable drift messages. Empty list means clean.
    """
    drift: list[str] = []
    for dsl_path in plugin_files:
        result = compile_plugin(dsl_path, write=False)
        expected_mcp = _build_mcp_json(_load_dsl(dsl_path))
        if result.mcp_json_path.exists():
            existing = json.loads(result.mcp_json_path.read_text(encoding="utf-8"))
            if existing != expected_mcp:
                drift.append(f"{result.mcp_json_path}: drift against {dsl_path}")
        else:
            drift.append(f"{result.mcp_json_path}: missing; compile has not been run")
        dsl = _load_dsl(dsl_path)
        for agent in dsl.get("agents") or []:
            if agent.get("runtime") != "kiro":
                continue
            expected_agent = _build_agent_json(dsl, agent)
            target = dsl_path.parent / "kiro-agents" / f"{agent['id']}.agent.json"
            if target.exists():
                current = json.loads(target.read_text(encoding="utf-8"))
                if current != expected_agent:
                    drift.append(f"{target}: drift against {dsl_path}")
            else:
                drift.append(f"{target}: missing; compile has not been run")
    return drift
